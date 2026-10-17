"""Check that CI analysis can use a limited token without local admin files."""

from argparse import Namespace
import base64
import os
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import analyze  # noqa: E402


class CiAuthenticationTests(unittest.TestCase):
    def test_environment_token_needs_no_admin_file_and_is_redacted(self):
        with TemporaryDirectory() as directory:
            with patch.object(analyze, 'LOCAL', Path(directory)):
                with patch.dict(os.environ, {'SONAR_HOST_URL': 'http://127.0.0.1:9000', 'SONAR_TOKEN': 'test-ci-token'}):
                    runner = analyze.Analysis(Namespace(use_environment_token=True))

            self.assertEqual(runner.token('ase-assms-job-service'), 'test-ci-token')
            self.assertEqual(runner.url, 'http://127.0.0.1:9000')
            self.assertEqual(runner.authorization, 'Basic ' + base64.b64encode(b'test-ci-token:').decode())
            self.assertEqual(runner.redact('token=test-ci-token'), 'token=[redacted]')
            self.assertNotIn('SONAR_TOKEN', runner.env)
            self.assertFalse((Path(directory) / 'admin-credentials.json').exists())
            self.assertFalse((Path(directory) / 'analysis-tokens.json').exists())


if __name__ == '__main__':
    unittest.main()
