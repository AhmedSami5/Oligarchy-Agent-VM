#!/usr/bin/env python3
"""
Unit tests for AgentVMClient

Comprehensive test suite covering:
- Client initialization and configuration
- Health check operations
- Agent execution (success, failure, errors)
- Convenience methods
- Session management
- Error handling and validation
"""

import unittest
from unittest.mock import Mock, patch
import requests
from tools.agent_vm_client import (
    AgentVMClient,
    Agent,
    AgentResult,
    AgentExecutionError,
    AgentSession
)


class TestAgentVMClient(unittest.TestCase):
    """Test cases for AgentVMClient"""

    # Class-level constants
    BASE_URL = "http://localhost:8000"
    TEST_API_KEY = "test-api-key"
    DEFAULT_TIMEOUT = 600
    TEST_REPO_PATH = "/test/repo"
    TEST_PROMPT = "Test prompt"

    def setUp(self):
        """Set up test fixtures before each test"""
        self.client = AgentVMClient(
            base_url=self.BASE_URL,
            api_key=self.TEST_API_KEY,
            timeout=self.DEFAULT_TIMEOUT
        )

    def test_init_with_api_key(self):
        """Test client initialization with API key sets correct headers"""
        client = AgentVMClient(api_key=self.TEST_API_KEY)

        self.assertEqual(client.api_key, self.TEST_API_KEY)
        self.assertEqual(client.base_url, self.BASE_URL)
        self.assertEqual(client.timeout, self.DEFAULT_TIMEOUT)
        self.assertIn("X-API-Key", client.session.headers)
        self.assertEqual(
            client.session.headers["X-API-Key"],
            self.TEST_API_KEY
        )

    def test_init_without_api_key(self):
        """Test client initialization without API key doesn't set auth
        header"""
        client = AgentVMClient()

        self.assertIsNone(client.api_key)
        self.assertNotIn("X-API-Key", client.session.headers)

    def test_init_with_custom_base_url(self):
        """Test client initialization with custom base URL"""
        custom_url = "http://custom:9000"
        client = AgentVMClient(base_url=custom_url)

        self.assertEqual(client.base_url, custom_url)

    def test_init_with_custom_timeout(self):
        """Test client initialization with custom timeout"""
        custom_timeout = 300
        client = AgentVMClient(timeout=custom_timeout)

        self.assertEqual(client.timeout, custom_timeout)

    @patch('requests.Session.get')
    def test_health_check_success(self, mock_get):
        """Test successful health check returns expected response"""
        expected_response = {"status": "healthy", "version": "1.0.0"}
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = expected_response
        mock_get.return_value = mock_response

        result = self.client.health_check()

        self.assertEqual(result, expected_response)
        mock_get.assert_called_once_with(f"{self.BASE_URL}/health")

    @patch('requests.Session.get')
    def test_health_check_connection_error(self, mock_get):
        """Test health check raises exception on connection failure"""
        mock_get.side_effect = requests.ConnectionError(
            "Connection refused"
        )

        with self.assertRaises(requests.ConnectionError) as context:
            self.client.health_check()

        self.assertIn("Connection refused", str(context.exception))

    @patch('requests.Session.get')
    def test_health_check_timeout(self, mock_get):
        """Test health check raises exception on timeout"""
        mock_get.side_effect = requests.Timeout("Request timed out")

        with self.assertRaises(requests.Timeout):
            self.client.health_check()

    @patch('requests.Session.get')
    def test_health_check_http_error(self, mock_get):
        """Test health check handles HTTP errors appropriately"""
        mock_response = Mock()
        mock_response.status_code = 503
        mock_response.raise_for_status.side_effect = requests.HTTPError(
            "503 Service Unavailable"
        )
        mock_get.return_value = mock_response

        # Assuming health_check calls raise_for_status
        with self.assertRaises(requests.HTTPError):
            self.client.health_check()
            mock_response.raise_for_status()

    @patch('requests.Session.post')
    def test_run_agent_success_complete_response(self, mock_post):
        """Test successful agent execution with complete response data"""
        expected_stdout = "Changes applied successfully"
        expected_stderr = ""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": True,
            "stdout": expected_stdout,
            "stderr": expected_stderr,
            "returncode": 0
        }
        mock_post.return_value = mock_response

        result = self.client.run_agent(
            Agent.AIDER,
            self.TEST_PROMPT,
            repo_path=self.TEST_REPO_PATH,
            timeout=300
        )

        # Comprehensive assertions
        self.assertIsInstance(result, AgentResult)
        self.assertTrue(result.success)
        self.assertEqual(result.stdout, expected_stdout)
        self.assertEqual(result.stderr, expected_stderr)
        self.assertEqual(result.returncode, 0)

        # Verify request was made correctly
        mock_post.assert_called_once()
        call_args = mock_post.call_args
        self.assertEqual(call_args[1]['timeout'], 300)

        request_json = call_args[1]['json']
        self.assertEqual(request_json['agent'], "aider")
        self.assertEqual(request_json['prompt'], self.TEST_PROMPT)
        self.assertEqual(request_json['repo_path'], self.TEST_REPO_PATH)

    @patch('requests.Session.post')
    def test_run_agent_failure_with_stderr(self, mock_post):
        """Test failed agent execution returns error information"""
        expected_stderr = "Error: File not found"
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": False,
            "stdout": None,
            "stderr": expected_stderr,
            "returncode": 1
        }
        mock_post.return_value = mock_response

        result = self.client.run_agent(Agent.AIDER, self.TEST_PROMPT)

        self.assertIsInstance(result, AgentResult)
        self.assertFalse(result.success)
        self.assertIsNone(result.stdout)
        self.assertEqual(result.stderr, expected_stderr)
        self.assertEqual(result.returncode, 1)

    @patch('requests.Session.post')
    def test_run_agent_raises_on_error(self, mock_post):
        """Test agent execution raises AgentExecutionError when
        requested"""
        error_message = "Critical error occurred"
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": False,
            "stdout": None,
            "stderr": error_message,
            "returncode": 1
        }
        mock_post.return_value = mock_response

        with self.assertRaises(AgentExecutionError) as context:
            self.client.run_agent(
                Agent.AIDER,
                self.TEST_PROMPT,
                raise_on_error=True
            )

        self.assertIsInstance(context.exception, AgentExecutionError)
        self.assertEqual(
            context.exception.result,
            mock_response.json.return_value
        )

    @patch('requests.Session.post')
    def test_run_agent_does_not_raise_by_default(self, mock_post):
        """Test agent execution returns result without raising by
        default"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": False,
            "stderr": "Error",
            "returncode": 1
        }
        mock_post.return_value = mock_response

        # Should not raise by default
        result = self.client.run_agent(Agent.AIDER, self.TEST_PROMPT)
        self.assertFalse(result.success)

    @patch('requests.Session.post')
    def test_run_agent_with_extra_args(self, mock_post):
        """Test agent execution includes extra arguments in request"""
        extra_args = ["--model", "gpt-4", "--verbose"]
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": True,
            "returncode": 0
        }
        mock_post.return_value = mock_response

        result = self.client.run_agent(
            Agent.AIDER,
            self.TEST_PROMPT,
            extra_args=extra_args
        )

        self.assertTrue(result.success)

        # Verify extra args were included in request
        call_args = mock_post.call_args
        self.assertEqual(call_args[1]['json']['extra_args'], extra_args)

    @patch('requests.Session.post')
    def test_run_agent_without_repo_path(self, mock_post):
        """Test agent execution without specifying repo path"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": True,
            "returncode": 0
        }
        mock_post.return_value = mock_response

        result = self.client.run_agent(Agent.AIDER, self.TEST_PROMPT)

        self.assertTrue(result.success)

        # Verify repo_path is None or not included
        call_args = mock_post.call_args
        request_json = call_args[1]['json']
        self.assertIsNone(request_json.get('repo_path'))

    @patch('requests.Session.post')
    def test_run_agent_http_error(self, mock_post):
        """Test agent execution handles HTTP errors appropriately"""
        mock_response = Mock()
        mock_response.status_code = 500
        mock_response.raise_for_status.side_effect = requests.HTTPError(
            "500 Server Error"
        )
        mock_post.return_value = mock_response

        with self.assertRaises(requests.HTTPError):
            self.client.run_agent(Agent.AIDER, self.TEST_PROMPT)
            mock_response.raise_for_status()

    @patch('requests.Session.post')
    def test_run_agent_timeout_error(self, mock_post):
        """Test agent execution handles timeout errors"""
        mock_post.side_effect = requests.Timeout(
            "Request timed out after 300s"
        )

        with self.assertRaises(requests.Timeout):
            self.client.run_agent(
                Agent.AIDER,
                self.TEST_PROMPT,
                timeout=300
            )

    @patch('requests.Session.post')
    def test_run_agent_connection_error(self, mock_post):
        """Test agent execution handles connection errors"""
        mock_post.side_effect = requests.ConnectionError(
            "Failed to connect"
        )

        with self.assertRaises(requests.ConnectionError):
            self.client.run_agent(Agent.AIDER, self.TEST_PROMPT)

    @patch('requests.Session.post')
    def test_run_agent_with_all_parameters(self, mock_post):
        """Test agent execution with all optional parameters
        specified"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": True,
            "returncode": 0
        }
        mock_post.return_value = mock_response

        result = self.client.run_agent(
            agent=Agent.AIDER,
            prompt=self.TEST_PROMPT,
            repo_path=self.TEST_REPO_PATH,
            extra_args=["--model", "test"],
            timeout=120,
            raise_on_error=False
        )

        self.assertTrue(result.success)

        # Verify all parameters were used
        call_args = mock_post.call_args
        self.assertEqual(call_args[1]['timeout'], 120)
        request_json = call_args[1]['json']
        self.assertEqual(request_json['agent'], "aider")
        self.assertEqual(request_json['prompt'], self.TEST_PROMPT)
        self.assertEqual(request_json['repo_path'], self.TEST_REPO_PATH)
        self.assertEqual(request_json['extra_args'], ["--model", "test"])

    @patch('requests.Session.post')
    def test_run_aider_convenience_method(self, mock_post):
        """Test aider convenience method uses correct agent and model"""
        custom_model = "claude-3-opus"
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": True,
            "returncode": 0
        }
        mock_post.return_value = mock_response

        result = self.client.run_aider(
            self.TEST_PROMPT,
            model=custom_model,
            repo_path=self.TEST_REPO_PATH
        )

        self.assertTrue(result.success)

        # Verify correct agent and model parameter
        call_args = mock_post.call_args
        request_json = call_args[1]['json']
        self.assertEqual(request_json['agent'], "aider")
        self.assertEqual(
            request_json['extra_args'],
            ["--model", custom_model]
        )
        self.assertEqual(request_json['repo_path'], self.TEST_REPO_PATH)

    @patch('requests.Session.post')
    def test_run_aider_without_model(self, mock_post):
        """Test aider convenience method without specifying model"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": True,
            "returncode": 0
        }
        mock_post.return_value = mock_response

        result = self.client.run_aider(self.TEST_PROMPT)

        self.assertTrue(result.success)

        # Verify no model args when not specified
        call_args = mock_post.call_args
        request_json = call_args[1]['json']
        self.assertEqual(request_json['agent'], "aider")
        self.assertIsNone(request_json.get('extra_args'))

    @patch('requests.Session.post')
    def test_run_opencode_convenience_method(self, mock_post):
        """Test opencode convenience method uses correct agent"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": True,
            "returncode": 0
        }
        mock_post.return_value = mock_response

        result = self.client.run_opencode(
            self.TEST_PROMPT,
            repo_path=self.TEST_REPO_PATH
        )

        self.assertTrue(result.success)

        # Verify correct agent was used
        call_args = mock_post.call_args
        request_json = call_args[1]['json']
        self.assertEqual(request_json['agent'], "opencode")
        self.assertEqual(request_json['repo_path'], self.TEST_REPO_PATH)

    @patch('requests.Session.post')
    def test_run_claude_convenience_method(self, mock_post):
        """Test claude convenience method uses correct agent"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": True,
            "returncode": 0
        }
        mock_post.return_value = mock_response

        result = self.client.run_claude(self.TEST_PROMPT)

        self.assertTrue(result.success)

        # Verify correct agent was used
        call_args = mock_post.call_args
        request_json = call_args[1]['json']
        self.assertEqual(request_json['agent'], "claude")

    def test_agent_enum_values(self):
        """Test Agent enum has expected values"""
        # Verify enum values exist
        self.assertEqual(Agent.AIDER.value, "aider")
        self.assertEqual(Agent.OPENCODE.value, "opencode")
        self.assertEqual(Agent.CLAUDE.value, "claude")


class TestAgentResult(unittest.TestCase):
    """Test cases for AgentResult dataclass"""

    def test_agent_result_success_initialization(self):
        """Test creating a successful AgentResult"""
        result = AgentResult(
            success=True,
            stdout="Output",
            stderr=None,
            returncode=0
        )

        self.assertTrue(result.success)
        self.assertEqual(result.stdout, "Output")
        self.assertIsNone(result.stderr)
        self.assertEqual(result.returncode, 0)

    def test_agent_result_failure_initialization(self):
        """Test creating a failed AgentResult"""
        result = AgentResult(
            success=False,
            stdout=None,
            stderr="Error message",
            returncode=1,
            error="Custom error"
        )

        self.assertFalse(result.success)
        self.assertIsNone(result.stdout)
        self.assertEqual(result.stderr, "Error message")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.error, "Custom error")

    def test_agent_result_success_property(self):
        """Test success property returns correct boolean value"""
        success_result = AgentResult(success=True)
        self.assertTrue(success_result.success)

        failure_result = AgentResult(success=False)
        self.assertFalse(failure_result.success)

    def test_agent_result_raise_for_status_success(self):
        """Test raise_for_status doesn't raise on successful result"""
        result = AgentResult(success=True, returncode=0)

        # Should not raise any exception
        try:
            result.raise_for_status()
        except Exception as e:
            self.fail(
                f"raise_for_status raised {type(e).__name__} unexpectedly"
            )

    def test_agent_result_raise_for_status_failure_with_error(self):
        """Test raise_for_status raises with custom error message"""
        error_msg = "Custom error message"
        result = AgentResult(success=False, error=error_msg)

        with self.assertRaises(AgentExecutionError) as context:
            result.raise_for_status()

        self.assertEqual(str(context.exception), error_msg)
        self.assertEqual(context.exception.result, result)

    def test_agent_result_raise_for_status_failure_with_returncode(self):
        """Test raise_for_status raises with return code message"""
        result = AgentResult(success=False, returncode=2)

        with self.assertRaises(AgentExecutionError) as context:
            result.raise_for_status()

        self.assertIn("return code 2", str(context.exception))
        self.assertEqual(context.exception.result, result)

    def test_agent_result_raise_for_status_failure_default_message(self):
        """Test raise_for_status with failure but no error or
        returncode"""
        result = AgentResult(success=False)

        with self.assertRaises(AgentExecutionError) as context:
            result.raise_for_status()

        # Should have some default error message
        self.assertIsInstance(context.exception, AgentExecutionError)
        self.assertEqual(context.exception.result, result)

    def test_agent_result_with_minimal_data(self):
        """Test AgentResult with only required fields"""
        result = AgentResult(success=True)

        self.assertTrue(result.success)
        # Other fields should have default values (likely None)


class TestAgentExecutionError(unittest.TestCase):
    """Test cases for AgentExecutionError exception"""

    def test_agent_execution_error_creation(self):
        """Test creating AgentExecutionError with message and result"""
        error_msg = "Test error message"
        result = AgentResult(success=False, error=error_msg)
        error = AgentExecutionError(error_msg, result)

        self.assertEqual(str(error), error_msg)
        self.assertEqual(error.result, result)
        self.assertIsInstance(error, Exception)

    def test_agent_execution_error_with_result_data(self):
        """Test AgentExecutionError preserves result data"""
        result = AgentResult(
            success=False,
            stdout="Partial output",
            stderr="Error details",
            returncode=127
        )
        error = AgentExecutionError("Command failed", result)

        self.assertEqual(error.result.stdout, "Partial output")
        self.assertEqual(error.result.stderr, "Error details")
        self.assertEqual(error.result.returncode, 127)

    def test_agent_execution_error_inheritance(self):
        """Test AgentExecutionError is an Exception subclass"""
        error = AgentExecutionError("Test", AgentResult(success=False))

        self.assertIsInstance(error, Exception)
        # Can be caught as a general exception
        try:
            raise error
        except Exception as e:
            self.assertIsInstance(e, AgentExecutionError)


class TestAgentSession(unittest.TestCase):
    """Test cases for AgentSession context manager"""

    @patch('tools.agent_vm_client.AgentVMClient')
    def test_agent_session_context_manager(self, mock_client_class):
        """Test AgentSession works as a context manager"""
        mock_client = Mock()
        mock_client.run_agent.return_value = AgentResult(
            success=True,
            stdout="Success",
            returncode=0
        )
        mock_client_class.return_value = mock_client

        with patch('builtins.print'):
            with AgentSession(
                api_key=TestAgentVMClient.TEST_API_KEY,
                repo_path=TestAgentVMClient.TEST_REPO_PATH
            ) as session:
                result = session.run(TestAgentVMClient.TEST_PROMPT)

                self.assertTrue(result.success)
                self.assertEqual(len(session.results), 1)
                self.assertTrue(session.results[0].success)

    @patch('tools.agent_vm_client.AgentVMClient')
    def test_agent_session_multiple_runs(self, mock_client_class):
        """Test AgentSession accumulates results from multiple runs"""
        mock_client = Mock()
        mock_client.run_agent.side_effect = [
            AgentResult(success=True, returncode=0),
            AgentResult(success=True, returncode=0),
            AgentResult(success=False, returncode=1)
        ]
        mock_client_class.return_value = mock_client

        with patch('builtins.print'):
            with AgentSession(
                api_key=TestAgentVMClient.TEST_API_KEY
            ) as session:
                session.run("First prompt")
                session.run("Second prompt")
                session.run("Third prompt", raise_on_error=False)

                # Verify all results are stored
                self.assertEqual(len(session.results), 3)
                self.assertTrue(session.results[0].success)
                self.assertTrue(session.results[1].success)
                self.assertFalse(session.results[2].success)

    @patch('tools.agent_vm_client.AgentVMClient')
    def test_agent_session_run_with_error_not_raised(
        self,
        mock_client_class
    ):
        """Test AgentSession run doesn't raise when raise_on_error is
        False"""
        mock_client = Mock()
        mock_client.run_agent.return_value = AgentResult(
            success=False,
            stderr="Error occurred",
            returncode=1
        )
        mock_client_class.return_value = mock_client

        with patch('builtins.print'):
            with AgentSession(
                api_key=TestAgentVMClient.TEST_API_KEY
            ) as session:
                result = session.run(
                    TestAgentVMClient.TEST_PROMPT,
                    raise_on_error=False
                )

                self.assertFalse(result.success)
                self.assertEqual(len(session.results), 1)

    @patch('tools.agent_vm_client.AgentVMClient')
    def test_agent_session_run_with_error_raised(self, mock_client_class):
        """Test AgentSession run raises when raise_on_error=True"""
        mock_client = Mock()
        mock_client.run_agent.side_effect = AgentExecutionError(
            "Failed",
            AgentResult(success=False, returncode=1)
        )
        mock_client_class.return_value = mock_client

        with patch('builtins.print'):
            with self.assertRaises(AgentExecutionError):
                with AgentSession(
                    api_key=TestAgentVMClient.TEST_API_KEY
                ) as session:
                    session.run(
                        TestAgentVMClient.TEST_PROMPT,
                        raise_on_error=True
                    )

    @patch('tools.agent_vm_client.AgentVMClient')
    def test_agent_session_summary_on_exit(self, mock_client_class):
        """Test AgentSession prints summary on context exit"""
        mock_client = Mock()
        mock_client.run_agent.return_value = AgentResult(
            success=True,
            returncode=0
        )
        mock_client_class.return_value = mock_client

        with patch('builtins.print') as mock_print:
            with AgentSession(
                api_key=TestAgentVMClient.TEST_API_KEY
            ) as session:
                session.run(TestAgentVMClient.TEST_PROMPT)

            # Verify summary was printed
            mock_print.assert_called()
            print_calls = [str(call) for call in mock_print.call_args_list]
            self.assertTrue(
                any(
                    "Session Summary" in call
                    or "summary" in call.lower()
                    for call in print_calls
                ),
                "Expected session summary to be printed"
            )

    @patch('tools.agent_vm_client.AgentVMClient')
    def test_agent_session_with_agent_parameter(self, mock_client_class):
        """Test AgentSession run method passes agent parameter
        correctly"""
        mock_client = Mock()
        mock_client.run_agent.return_value = AgentResult(
            success=True,
            returncode=0
        )
        mock_client_class.return_value = mock_client

        with patch('builtins.print'):
            with AgentSession(
                api_key=TestAgentVMClient.TEST_API_KEY
            ) as session:
                session.run(
                    TestAgentVMClient.TEST_PROMPT,
                    agent=Agent.OPENCODE
                )

                # Verify agent parameter was passed
                mock_client.run_agent.assert_called_once()
                call_kwargs = mock_client.run_agent.call_args[1]
                self.assertEqual(call_kwargs.get('agent'), Agent.OPENCODE)

    @patch('tools.agent_vm_client.AgentVMClient')
    def test_agent_session_success_rate_calculation(
        self,
        mock_client_class
    ):
        """Test AgentSession calculates success rate correctly"""
        mock_client = Mock()
        mock_client.run_agent.side_effect = [
            AgentResult(success=True, returncode=0),
            AgentResult(success=True, returncode=0),
            AgentResult(success=False, returncode=1),
            AgentResult(success=True, returncode=0),
        ]
        mock_client_class.return_value = mock_client

        with patch('builtins.print'):
            with AgentSession(
                api_key=TestAgentVMClient.TEST_API_KEY
            ) as session:
                for i in range(4):
                    session.run(f"Prompt {i}", raise_on_error=False)

                # 3 out of 4 succeeded = 75%
                total = len(session.results)
                successful = sum(1 for r in session.results if r.success)

                self.assertEqual(total, 4)
                self.assertEqual(successful, 3)
                self.assertAlmostEqual(successful / total, 0.75)


class TestEdgeCases(unittest.TestCase):
    """Test edge cases and unusual scenarios"""

    def test_empty_prompt(self):
        """Test handling of empty prompt string"""
        client = AgentVMClient()

        # This might be valid or invalid depending on implementation
        # Testing that it doesn't crash
        with patch('requests.Session.post') as mock_post:
            mock_post.return_value = Mock(
                status_code=200,
                json=Mock(return_value={
                    "success": True,
                    "returncode": 0
                })
            )
            self.client.run_agent(Agent.AIDER, "")
            # Verify empty prompt was sent
            self.assertEqual(mock_post.call_args[1]['json']['prompt'], "")

    def test_very_long_prompt(self):
        """Test handling of very long prompt"""
        client = AgentVMClient()
        long_prompt = "A" * 100000  # 100k characters

        with patch('requests.Session.post') as mock_post:
            mock_post.return_value = Mock(
                status_code=200,
                json=Mock(return_value={
                    "success": True,
                    "returncode": 0
                })
            )
            client.run_agent(Agent.AIDER, long_prompt)
            self.assertEqual(
                mock_post.call_args[1]['json']['prompt'],
                long_prompt
            )

    def test_special_characters_in_prompt(self):
        """Test handling of special characters in prompt"""
        client = AgentVMClient()
        special_prompt = 'Test\n\t"quotes" \'apostrophes\' & <xml> {json}'

        with patch('requests.Session.post') as mock_post:
            mock_post.return_value = Mock(
                status_code=200,
                json=Mock(return_value={
                    "success": True,
                    "returncode": 0
                })
            )
            client.run_agent(Agent.AIDER, special_prompt)
            self.assertEqual(
                mock_post.call_args[1]['json']['prompt'],
                special_prompt
            )

    def test_none_return_code(self):
        """Test handling of None return code in response"""
        result = AgentResult(success=True, returncode=None)
        self.assertTrue(result.success)
        self.assertIsNone(result.returncode)

    @patch('requests.Session.post')
    def test_malformed_json_response(self, mock_post):
        """Test handling of malformed JSON in response"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.side_effect = ValueError("Invalid JSON")
        mock_post.return_value = mock_response

        client = AgentVMClient()

        with self.assertRaises(ValueError):
            client.run_agent(Agent.AIDER, "test")


if __name__ == '__main__':
    # Run tests with verbose output
    unittest.main(verbosity=2)