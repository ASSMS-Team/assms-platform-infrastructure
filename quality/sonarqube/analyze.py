"""Run isolated local ASE coverage and SonarQube analyses using existing tests."""

import argparse
import base64
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
LOCAL = HERE / '.local'
SETTINGS = json.loads((HERE / 'analysis-settings.json').read_text(encoding='utf-8'))
METRICS = 'coverage,line_coverage,branch_coverage,lines_to_cover,uncovered_lines,duplicated_lines_density,ncloc,complexity,cognitive_complexity,code_smells,bugs,vulnerabilities,security_hotspots,sqale_index,sqale_debt_ratio,tests,test_errors,test_failures,skipped_tests'


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')


class Analysis:
    def __init__(self, args):
        self.args = args
        self.stamp = datetime.now().strftime('%Y%m%dT%H%M%S%f')
        self.output = LOCAL / 'analysis-runs' / self.stamp
        self.output.mkdir(parents=True)
        self.environment_token = None
        if args.use_environment_token:
            self.url = os.environ.get('SONAR_HOST_URL', '').rstrip('/')
            self.environment_token = os.environ.get('SONAR_TOKEN', '')
            if not self.url or not self.environment_token:
                raise RuntimeError('SONAR_HOST_URL and SONAR_TOKEN are required with --use-environment-token.')
            self.authorization = 'Basic ' + base64.b64encode(f'{self.environment_token}:'.encode()).decode()
            self.secrets = [self.environment_token]
            self.tokens = {}
        else:
            credentials = read_json(LOCAL / 'admin-credentials.json')
            self.url = credentials['url'].rstrip('/')
            self.authorization = 'Basic ' + base64.b64encode(f"{credentials['username']}:{credentials['password']}".encode()).decode()
            self.secrets = [credentials['password']]
            token_path = LOCAL / 'analysis-tokens.json'
            self.tokens = read_json(token_path) if token_path.exists() else {}
            self.secrets.extend(item['token'] for item in self.tokens.values())
        self.env = dict(os.environ, CI='true', NO_COLOR='1', DOTNET_NOLOGO='1', DOTNET_CLI_TELEMETRY_OPTOUT='1', SONAR_USER_HOME=str(LOCAL / 'scanner-cache'))
        self.env.pop('ASSMS_DISPATCH_TEST_CONNECTION', None)
        self.env.pop('SONAR_TOKEN', None)
        self.report = {'runId': self.stamp, 'startedUtc': datetime.now(timezone.utc).isoformat(), 'scope': 'ASE existing-test coverage and local static analysis', 'serverUrl': self.url, 'scannerVersions': {'dotnet': SETTINGS['dotnetScannerVersion'], 'cli': SETTINGS['cliScannerVersion']}, 'projects': {}}

    def redact(self, value):
        value = str(value)
        for secret in self.secrets:
            value = value.replace(secret, '[redacted]')
        return re.sub(r'\b(?:sqp|sqa|squ)_[A-Za-z0-9]+', '[redacted-token]', value)

    def api(self, path, body=None):
        data = urlencode(body).encode() if body is not None else None
        request = Request(self.url + path, data=data, headers={'Authorization': self.authorization})
        try:
            with urlopen(request, timeout=45) as response:
                content = response.read()
                return json.loads(content) if content else {}
        except HTTPError as error:
            raise RuntimeError(f'SonarQube API {path.split("?")[0]} returned HTTP {error.code}') from None

    def save(self):
        write_json(self.output / 'summary.json', self.report)

    def command(self, repo, label, command, env=None, timeout=1200):
        item = self.report['projects'][repo.name]
        log = Path(item['artifacts']) / f'{label}.log'
        print(f'RUN {repo.name}: {label}', flush=True)
        start = time.monotonic()
        with log.open('w', encoding='utf-8') as output:
            process = subprocess.Popen(command, cwd=repo, env=env or self.env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            def copy_output():
                for line in iter(process.stdout.readline, b''):
                    output.write(self.redact(line.decode('utf-8', errors='replace')))
                    output.flush()
            reader = threading.Thread(target=copy_output, daemon=True)
            reader.start()
            try:
                process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                reader.join(timeout=10)
                raise RuntimeError(f'{label} exceeded {timeout} seconds; see {log}') from None
            reader.join(timeout=10)
        item['steps'][label] = {'command': [self.redact(a) for a in command], 'exitCode': process.returncode, 'seconds': round(time.monotonic() - start, 2), 'log': str(log)}
        self.save()
        if process.returncode:
            print('\n'.join(log.read_text(encoding='utf-8').splitlines()[-12:]), flush=True)
            raise RuntimeError(f'{label} failed with exit code {process.returncode}; see {log}')
        print(f'PASS {repo.name}: {label}', flush=True)

    def git(self, repo, *args):
        return subprocess.check_output(['git', '-c', f'safe.directory={repo.as_posix()}', '-C', str(repo), *args], text=True).strip()

    def token(self, key):
        if self.environment_token:
            return self.environment_token
        today = datetime.now(timezone.utc).date()
        existing = self.tokens.get(key)
        if existing and datetime.fromisoformat(existing['expirationDate']).date() > today:
            return existing['token']
        expiry = (today + timedelta(days=30)).isoformat()
        result = self.api('/api/user_tokens/generate', {'name': f'{key}-{self.stamp}', 'type': 'PROJECT_ANALYSIS_TOKEN', 'projectKey': key, 'expirationDate': expiry})
        self.secrets.append(result['token'])
        self.tokens[key] = {'token': result['token'], 'expirationDate': expiry, 'name': result['name']}
        write_json(LOCAL / 'analysis-tokens.json', self.tokens)
        return result['token']

    def dotnet(self):
        if hasattr(self, 'dotnet_exe'):
            return self.dotnet_exe
        local_sdk = ROOT / 'temp/dotnet-sdk8/dotnet.exe'
        value = self.args.dotnet or (str(local_sdk) if local_sdk.exists() else shutil.which('dotnet'))
        if not value:
            raise RuntimeError('Install .NET 8 SDK or supply --dotnet with its executable path.')
        self.dotnet_exe = str(Path(value).resolve())
        self.env['DOTNET_ROOT'] = str(Path(self.dotnet_exe).parent)
        self.env['PATH'] = str(Path(self.dotnet_exe).parent) + os.pathsep + self.env.get('PATH', '')
        return self.dotnet_exe

    def scanner(self, repo):
        version = SETTINGS['dotnetScannerVersion']
        store = LOCAL / f'tools/.store/dotnet-sonarscanner/{version}'
        matches = list(store.rglob('SonarScanner.MSBuild.dll')) if store.exists() else []
        if not matches:
            self.command(repo, 'install-dotnet-scanner', [self.dotnet(), 'tool', 'install', 'dotnet-sonarscanner', '--version', version, '--tool-path', str(LOCAL / 'tools')])
            matches = list(store.rglob('SonarScanner.MSBuild.dll'))
        if len(matches) != 1:
            raise RuntimeError('Could not locate the pinned .NET scanner DLL.')
        return [self.dotnet(), str(matches[0])]

    def test_counts(self, trx):
        counters = ET.parse(trx).find('.//{http://microsoft.com/schemas/VisualStudio/TeamTest/2010}Counters')
        if counters is None:
            raise RuntimeError('Test result counters are missing.')
        counts = {key: int(counters.get(key, '0')) for key in ('total', 'executed', 'passed', 'failed')}
        counts['skipped'] = counts['total'] - counts['executed']
        return counts

    def cli_scanner(self, repo):
        version = SETTINGS['cliScannerVersion']
        tools = LOCAL / 'tools'
        tools.mkdir(parents=True, exist_ok=True)
        archive = tools / f'sonar-scanner-cli-{version}.zip'
        if not archive.exists():
            url = f'https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/{archive.name}'
            print(f'Download official SonarScanner CLI {version}', flush=True)
            with urlopen(url, timeout=120) as response, archive.open('wb') as output:
                shutil.copyfileobj(response, output)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != SETTINGS['cliScannerSha256']:
            raise RuntimeError('Standalone scanner archive checksum does not match the pinned official download.')
        home = tools / f'sonar-scanner-{version}'
        if not home.exists():
            with zipfile.ZipFile(archive) as package:
                for name in package.namelist():
                    if not (tools / name).resolve().is_relative_to(tools.resolve()):
                        raise RuntimeError('Unsafe path in scanner archive.')
                package.extractall(tools)
        java_home = self.env.get('JAVA_HOME')
        java_name = 'java.exe' if os.name == 'nt' else 'java'
        java = Path(java_home) / 'bin' / java_name if java_home else None
        if java is None or not java.exists():
            discovered = shutil.which('java')
            java = Path(discovered) if discovered else Path(r'C:\Program Files\Java\jdk-21\bin\java.exe')
        if not java.exists():
            raise RuntimeError('Install Java 21 and set JAVA_HOME for the standalone frontend scanner.')
        jar = home / f'lib/sonar-scanner-cli-{version}.jar'
        return [str(java), f'-Dscanner.home={home}', f'-Dproject.home={repo}', '-cp', str(jar), 'org.sonarsource.scanner.cli.Main']

    def analyze_dotnet(self, project, repo, artifacts, token, revision):
        scanner = self.scanner(repo)
        normalized = artifacts.as_posix()
        self.command(repo, 'scanner-begin', scanner + ['begin', f"/k:{project['projectKey']}", f'/v:{revision[:12]}', f'/d:sonar.host.url={self.url}', f'/d:sonar.token={token}', '/d:sonar.scanner.scanAll=false', f'/d:sonar.cs.opencover.reportsPaths={normalized}/TestResults/**/coverage.opencover.xml', f'/d:sonar.cs.vstest.reportsPaths={normalized}/TestResults/*.trx', '/d:sonar.exclusions=**/bin/**,**/obj/**,.sonarqube/**,quality/artifacts/**'])
        try:
            self.command(repo, 'build', [self.dotnet(), 'build', project['solution'], '--configuration', 'Release', '--no-incremental', '--disable-build-servers', '--verbosity', 'minimal'])
            self.command(repo, 'tests-and-coverage', [self.dotnet(), 'test', project['solution'], '--configuration', 'Release', '--no-build', '--no-restore', '--settings', str(repo / 'quality/coverage.runsettings'), '--collect:XPlat Code Coverage', '--results-directory', str(artifacts / 'TestResults'), '--logger', 'trx;LogFileName=tests.trx', '--verbosity', 'minimal'])
            reports = list((artifacts / 'TestResults').rglob('coverage.opencover.xml'))
            if not reports:
                raise RuntimeError('Coverlet did not produce an OpenCover report; refusing an analysis without coverage.')
            item = self.report['projects'][repo.name]
            item['tests'] = self.test_counts(artifacts / 'TestResults/tests.trx')
            item['coverageReports'] = [str(p) for p in reports]
        except Exception:
            # Do not publish a partial result as a successful analysis.
            raise
        self.command(repo, 'scanner-end', scanner + ['end', f'/d:sonar.token={token}'])
        return repo / '.sonarqube/out/.sonar/report-task.txt'

    def analyze_frontend(self, project, repo, artifacts, token, revision):
        npm = shutil.which('npm.cmd') or shutil.which('npm')
        if not npm:
            raise RuntimeError('Node.js and npm are required for frontend analysis.')
        self.command(repo, 'install', [npm, 'ci', '--no-audit', '--no-fund'])
        self.command(repo, 'lint', [npm, 'run', 'lint'])
        self.command(repo, 'build', [npm, 'run', 'build'])
        results = artifacts / 'vitest.json'
        self.command(repo, 'tests-and-coverage', [npm, 'run', 'test:coverage', '--', f'--coverage.reportsDirectory={artifacts / "coverage"}', '--reporter=default', '--reporter=json', f'--outputFile={results}'])
        vitest = read_json(results)
        item = self.report['projects'][repo.name]
        item['tests'] = {'total': vitest['numTotalTests'], 'passed': vitest['numPassedTests'], 'failed': vitest['numFailedTests'], 'skipped': vitest['numPendingTests']}
        lcov = artifacts / 'coverage/lcov.info'
        if not lcov.exists():
            raise RuntimeError('Vitest did not produce LCOV coverage; refusing an analysis without coverage.')
        item['coverageReports'] = [str(lcov)]
        scanner_env = dict(self.env, SONAR_TOKEN=token, SONAR_HOST_URL=self.url)
        cli = self.cli_scanner(repo)
        self.command(repo, 'scanner', cli + ['-Dsonar.scanner.skipJreProvisioning=true', f'-Dsonar.scanner.javaExePath={cli[0]}', f'-Dsonar.projectVersion={revision[:12]}', f'-Dsonar.javascript.lcov.reportPaths={lcov.as_posix()}'], env=scanner_env)
        return repo / '.scannerwork/report-task.txt'

    def collect(self, project, task_file, artifacts):
        if not task_file.exists():
            raise RuntimeError(f'Scanner task metadata is missing: {task_file}')
        task = dict(line.split('=', 1) for line in task_file.read_text(encoding='utf-8').splitlines() if '=' in line)
        (artifacts / 'report-task.txt').write_text(task_file.read_text(encoding='utf-8'), encoding='utf-8')
        deadline = time.monotonic() + 600
        while True:
            result = self.api('/api/ce/task?' + urlencode({'id': task['ceTaskId']}))
            status = result['task']['status']
            if status in ('SUCCESS', 'FAILED', 'CANCELED'):
                break
            if time.monotonic() > deadline:
                raise RuntimeError('SonarQube background processing exceeded ten minutes.')
            time.sleep(2)
        write_json(artifacts / 'background-task.json', result)
        if status != 'SUCCESS':
            raise RuntimeError(f'SonarQube background task ended with {status}')
        key = project['projectKey']
        measures = self.api('/api/measures/component?' + urlencode({'component': key, 'metricKeys': METRICS}))
        gate = self.api('/api/qualitygates/project_status?' + urlencode({'analysisId': result['task']['analysisId']}))
        issues = self.api('/api/issues/search?' + urlencode({'componentKeys': key, 'resolved': 'false', 'ps': 1}))
        write_json(artifacts / 'sonarqube-metrics.json', measures)
        write_json(artifacts / 'quality-gate.json', gate)
        item = self.report['projects'][project['repository']]
        item['metrics'] = {m['metric']: m.get('value') for m in measures['component']['measures']}
        item['qualityGate'] = gate['projectStatus']['status']
        item['evaluatedQualityGateConditions'] = len(gate['projectStatus']['conditions'])
        item['openIssues'] = issues['paging']['total']
        item['analysisId'] = result['task']['analysisId']
        item['dashboardUrl'] = task['dashboardUrl']
        item['scannerDiagnostics'] = [line.strip() for log in artifacts.glob('scanner*.log') for line in log.read_text(encoding='utf-8', errors='replace').splitlines() if re.search(r'\b(?:WARN|ERROR)\b', line)]
        item['status'] = 'ANALYZED'
        print(f"ANALYZED {project['repository']}: coverage {item['metrics'].get('coverage', 'unavailable')}%; gate {item['qualityGate']}; open issues {item['openIssues']}", flush=True)

    def run(self):
        self.report['server'] = self.api('/api/system/status')
        if self.report['server']['status'] != 'UP':
            raise RuntimeError('Start SonarQube and wait for UP before running analysis.')
        selected = [p for p in SETTINGS['projects'] if 'all' in self.args.project or p['id'] in self.args.project]
        for project in selected:
            repo = ROOT / project['repository']
            artifacts = repo / 'quality/artifacts' / self.stamp
            artifacts.mkdir(parents=True)
            revision = self.git(repo, 'rev-parse', 'HEAD')
            item = {'status': 'STARTED', 'revision': revision, 'branch': self.git(repo, 'branch', '--show-current'), 'workingTreeChanges': self.git(repo, 'status', '--short'), 'artifacts': str(artifacts), 'steps': {}}
            self.report['projects'][repo.name] = item
            for name in ('quality/coverage.runsettings', 'vitest.config.ts', 'sonar-project.properties', 'package.json', 'package-lock.json'):
                source = repo / name
                if source.exists():
                    destination = artifacts / 'configuration' / name
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, destination)
            self.save()
            try:
                token = self.token(project['projectKey'])
                if 'solution' in project:
                    task_file = self.analyze_dotnet(project, repo, artifacts, token, revision)
                else:
                    task_file = self.analyze_frontend(project, repo, artifacts, token, revision)
                self.collect(project, task_file, artifacts)
                item['coverageReportSha256'] = {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in item['coverageReports']}
            except Exception as error:
                item['status'] = 'FAILED'
                item['error'] = self.redact(error)
                print(f"FAILED {repo.name}: {item['error']}", flush=True)
            self.save()
        self.report['completedUtc'] = datetime.now(timezone.utc).isoformat()
        self.report['allAnalysesSucceeded'] = all(p['status'] == 'ANALYZED' for p in self.report['projects'].values())
        self.report['allQualityGatesPassed'] = all(p.get('qualityGate') == 'OK' for p in self.report['projects'].values())
        self.save()
        print(f'Summary: {self.output / "summary.json"}', flush=True)
        if not self.report['allAnalysesSucceeded']:
            return 1
        return 2 if self.args.fail_on_quality_gate and not self.report['allQualityGatesPassed'] else 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', choices=['all'] + [p['id'] for p in SETTINGS['projects']], nargs='+', default=['all'])
    parser.add_argument('--dotnet')
    parser.add_argument('--use-environment-token', action='store_true')
    parser.add_argument('--fail-on-quality-gate', action='store_true')
    arguments = parser.parse_args()
    try:
        sys.exit(Analysis(arguments).run())
    except Exception as error:
        # Only print the error type here; exceptions may contain private API data.
        print(f'Analysis setup failed ({type(error).__name__}). Check SonarQube and the private local configuration.', file=sys.stderr)
        sys.exit(1)
