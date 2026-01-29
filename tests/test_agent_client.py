#!/usr/bin/env python3
"""
Unit tests for AgentVMClient
"""

import unittest
from unittest.mock import Mock, patch
import requests
from tools.agent_vm_client import AgentVMClient, Agent, AgentResult, AgentExecutionError


class TestAgentVMClient(unittest.TestCase):
    """Test cases for AgentVMClient"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.base_url = "http://localhost:8000"
        self.api_key = "test-key"
        self.client = AgentVMClient(
            base_url=self.base_url,
            api_key=self.api_key,
            timeout=600
        )
    
    def test_init_with_api_key(self):
        """Test client initialization with API key"""
        client = AgentVMClient(api_key="test-key")
        self.assertEqual(client.api_key, "test-key")
        self.assertEqual(client.base_url, "http://localhost:8000")
        self.assertEqual(client.timeout, 600)
        self.assertIn("X-API-Key", client.session.headers)
        self.assertEqual(client.session.headers["X-API-Key"], "test-key")
    
    def test_init_without_api_key(self):
        """Test client initialization without API key"""
        client = AgentVMClient()
        self.assertIsNone(client.api_key)
        self.assertNotIn("X-API-Key", client.session.headers)
    
    @patch('requests.Session.get')
    def test_health_check_success(self, mock_get):
        """Test successful health check"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"status": "healthy"}
        mock_get.return_value = mock_response
        
        result = self.client.health_check()
        
        self.assertEqual(result, {"status": "healthy"})
        mock_get.assert_called_once_with(f"{self.base_url}/health")
    
    @patch('requests.Session.get')
    def test_health_check_failure(self, mock_get):
        """Test failed health check"""
        mock_get.side_effect = requests.RequestException("Connection failed")
        
        with self.assertRaises(requests.RequestException):
            self.client.health_check()
    
    @patch('requests.Session.post')
    def test_run_agent_success(self, mock_post):
        """Test successful agent execution"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": True,
            "stdout": "Changes applied",
            "stderr": None,
            "returncode": 0
        }
        mock_post.return_value = mock_response
        
        result = self.client.run_agent(
            Agent.AIDER,
            "Test prompt",
            repo_path="/test/repo",
            timeout=300
        )
        
        self.assertIsInstance(result, AgentResult)
        self.assertTrue(result.success)
        self.assertEqual(result.stdout, "Changes applied")
        self.assertIsNone(result.stderr)
        self.assertEqual(result.returncode, 0)
        
        # Verify request was made correctly
        mock_post.assert_called_once()
        call_args = mock_post.call_args
        self.assertEqual(call_args[1]['timeout'], 300)
        self.assertEqual(call_args[1]['json']['agent'], "aider")
        self.assertEqual(call_args[1]['json']['prompt'], "Test prompt")
        self.assertEqual(call_args[1]['json']['repo_path'], "/test/repo")
    
    @patch('requests.Session.post')
    def test_run_agent_failure(self, mock_post):
        """Test failed agent execution"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": False,
            "stdout": None,
            "stderr": "Error occurred",
            "returncode": 1
        }
        mock_post.return_value = mock_response
        
        result = self.client.run_agent(Agent.AIDER, "Test prompt")
        
        self.assertIsInstance(result, AgentResult)
        self.assertFalse(result.success)
        self.assertIsNone(result.stdout)
        self.assertEqual(result.stderr, "Error occurred")
        self.assertEqual(result.returncode, 1)
    
    @patch('requests.Session.post')
    def test_run_agent_raises_on_error(self, mock_post):
        """Test agent execution raises exception when requested"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": False,
            "stdout": None,
            "stderr": "Error occurred",
            "returncode": 1
        }
        mock_post.return_value = mock_response
        
        with self.assertRaises(AgentExecutionError) as context:
            self.client.run_agent(Agent.AIDER, "Test prompt", raise_on_error=True)
        
        self.assertIsInstance(context.exception, AgentExecutionError)
        self.assertEqual(context.exception.result, mock_response.json.return_value)
    
    @patch('requests.Session.post')
    def test_run_agent_with_extra_args(self, mock_post):
        """Test agent execution with extra arguments"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"success": True}
        mock_post.return_value = mock_response
        
        result = self.client.run_agent(
            Agent.AIDER,
            "Test prompt",
            extra_args=["--model", "test-model"]
        )
        
        self.assertTrue(result.success)
        
        # Verify extra args were included
        call_args = mock_post.call_args
        self.assertEqual(call_args[1]['json']['extra_args'], ["--model", "test-model"])
    
    @patch('requests.Session.post')
    def test_run_aider_convenience_method(self, mock_post):
        """Test aider convenience method"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"success": True}
        mock_post.return_value = mock_response
        
        result = self.client.run_aider("Test prompt", model="custom-model")
        
        self.assertTrue(result.success)
        
        # Verify correct agent and model were used
        call_args = mock_post.call_args
        self.assertEqual(call_args[1]['json']['agent'], "aider")
        self.assertEqual(call_args[1]['json']['extra_args'], ["--model", "custom-model"])
    
    @patch('requests.Session.post')
    def test_run_opencode_convenience_method(self, mock_post):
        """Test opencode convenience method"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"success": True}
        mock_post.return_value = mock_response
        
        result = self.client.run_opencode("Test prompt")
        
        self.assertTrue(result.success)
        
        # Verify correct agent was used
        call_args = mock_post.call_args
        self.assertEqual(call_args[1]['json']['agent'], "opencode")
    
    @patch('requests.Session.post')
    def test_run_claude_convenience_method(self, mock_post):
        """Test claude convenience method"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"success": True}
        mock_post.return_value = mock_response
        
        result = self.client.run_claude("Test prompt")
        
        self.assertTrue(result.success)
        
        # Verify correct agent was used
        call_args = mock_post.call_args
        self.assertEqual(call_args[1]['json']['agent'], "claude")


class TestAgentResult(unittest.TestCase):
    """Test cases for AgentResult"""
    
    def test_agent_result_success_property(self):
        """Test success property of AgentResult"""
        success_result = AgentResult(success=True)
        self.assertTrue(success_result.success)
        
        failure_result = AgentResult(success=False)
        self.assertFalse(failure_result.success)
    
    def test_agent_result_raise_for_status_success(self):
        """Test raise_for_status with successful result"""
        result = AgentResult(success=True)
        # Should not raise
        result.raise_for_status()
    
    def test_agent_result_raise_for_status_failure_with_error(self):
        """Test raise_for_status with failed result and error message"""
        result = AgentResult(success=False, error="Test error")
        
        with self.assertRaises(AgentExecutionError) as context:
            result.raise_for_status()
        
        self.assertEqual(str(context.exception), "Test error")
        self.assertEqual(context.exception.result, result)
    
    def test_agent_result_raise_for_status_failure_with_returncode(self):
        """Test raise_for_status with failed result and return code"""
        result = AgentResult(success=False, returncode=1)
        
        with self.assertRaises(AgentExecutionError) as context:
            result.raise_for_status()
        
        self.assertEqual(str(context.exception), "Agent failed with return code 1")
        self.assertEqual(context.exception.result, result)


class TestAgentExecutionError(unittest.TestCase):
    """Test cases for AgentExecutionError"""
    
    def test_agent_execution_error_creation(self):
        """Test creation of AgentExecutionError"""
        result = AgentResult(success=False, error="Test error")
        error = AgentExecutionError("Test error", result)
        
        self.assertEqual(str(error), "Test error")
        self.assertEqual(error.result, result)


class TestAgentSession(unittest.TestCase):
    """Test cases for AgentSession"""
    
    @patch('tools.agent_vm_client.AgentVMClient')
    def test_agent_session_context_manager(self, mock_client_class):
        """Test AgentSession as context manager"""
        mock_client = Mock()
        mock_client.run_agent.return_value = AgentResult(success=True)
        mock_client_class.return_value = mock_client
        
        with patch('builtins.print') as mock_print:
            with AgentSession(api_key="test-key", repo_path="/test/repo") as session:
                result = session.run("Test prompt")
                
                self.assertTrue(result.success)
                self.assertEqual(len(session.results), 1)
                self.assertTrue(session.results[0].success)
        
        # Verify summary was printed
        mock_print.assert_called()
        print_calls = [str(call) for call in mock_print.call_args_list]
        self.assertTrue(any("Session Summary" in call for call in print_calls))
    
    @patch('tools.agent_vm_client.AgentVMClient')
    def test_agent_session_run_with_error(self, mock_client_class):
        """Test AgentSession run method with error"""
        mock_client = Mock()
        mock_client.run_agent.return_value = AgentResult(success=False)
        mock_client_class.return_value = mock_client
        
        with patch('builtins.print') as mock_print:
            with AgentSession(api_key="test-key") as session:
                result = session.run("Test prompt", raise_on_error=False)
                
                self.assertFalse(result.success)
                self.assertEqual(len(session.results), 1)
                self.assertFalse(session.results[0].success)


if __name__ == '__main__':
    unittest.main()