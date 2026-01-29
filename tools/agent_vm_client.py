#!/usr/bin/env python3
"""
Oligarchy AgentVM Python Client Library

A high-level Python client for interacting with the AgentVM REST API.
Makes it easy to orchestrate AI coding agents programmatically.

Example usage:
    from agent_vm_client import AgentVMClient
    
    client = AgentVMClient(api_key="your-key")
    result = client.run_aider("Fix the bug in auth.py")
    print(result.stdout)
"""

import requests
from typing import Optional, List, Dict, Any
from dataclasses import dataclass
from enum import Enum


class Agent(str, Enum):
    """Available AI coding agents"""
    AIDER = "aider"
    OPENCODE = "opencode"
    CLAUDE = "claude"


@dataclass
class AgentResult:
    """Result from running an agent"""
    success: bool
    stdout: Optional[str] = None
    stderr: Optional[str] = None
    returncode: Optional[int] = None
    error: Optional[str] = None
    
    @property
    def failed(self) -> bool:
        """Check if agent execution failed"""
        return not self.success
    
    def raise_for_status(self):
        """Raise exception if agent failed"""
        if self.failed:
            msg = self.error or f"Agent failed with return code {self.returncode}"
            raise AgentExecutionError(msg, self)


class AgentExecutionError(Exception):
    """Raised when agent execution fails"""
    def __init__(self, message: str, result: AgentResult):
        super().__init__(message)
        self.result = result


class AgentVMClient:
    """
    Client for Oligarchy AgentVM REST API
    
    Args:
        base_url: Base URL of the AgentVM API (default: http://localhost:8000)
        api_key: API key for authentication
        timeout: Default timeout for requests in seconds
        
    Example:
        >>> client = AgentVMClient(api_key="your-key")
        >>> result = client.run_aider("Add error handling")
        >>> print(result.stdout)
    """
    
    def __init__(
        self,
        base_url: str = "http://localhost:8000",
        api_key: Optional[str] = None,
        timeout: int = 600
    ):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.timeout = timeout
        self.session = requests.Session()
        
        if api_key:
            self.session.headers.update({
                "X-API-Key": api_key,
                "Content-Type": "application/json"
            })
    
    def health_check(self) -> Dict[str, Any]:
        """
        Check if the API is healthy
        
        Returns:
            Dict with status information
            
        Raises:
            requests.RequestException: If request fails
        """
        response = self.session.get(f"{self.base_url}/health")
        response.raise_for_status()
        return response.json()
    
    def run_agent(
        self,
        agent: Agent,
        prompt: str,
        repo_path: Optional[str] = None,
        timeout: Optional[int] = None,
        extra_args: Optional[List[str]] = None,
        raise_on_error: bool = False
    ) -> AgentResult:
        """
        Run an AI coding agent with the specified prompt
        
        Args:
            agent: Which agent to run (use Agent enum)
            prompt: Coding task or instruction
            repo_path: Path to repository (default: /mnt/host-projects/current)
            timeout: Execution timeout in seconds (default: self.timeout)
            extra_args: Additional command-line arguments
            raise_on_error: Raise exception if agent fails
            
        Returns:
            AgentResult object with execution details
            
        Raises:
            AgentExecutionError: If raise_on_error=True and agent fails
            requests.RequestException: If API request fails
            
        Example:
            >>> result = client.run_agent(
            ...     Agent.AIDER,
            ...     "Add logging to the API endpoints",
            ...     repo_path="/mnt/host-projects/my-app"
            ... )
            >>> if result.success:
            ...     print("Success!")
        """
        payload = {
            "agent": agent.value if isinstance(agent, Agent) else agent,
            "prompt": prompt,
            "repo_path": repo_path or "/mnt/host-projects/current",
            "timeout": timeout or self.timeout,
        }
        
        if extra_args:
            payload["extra_args"] = extra_args
        
        response = self.session.post(
            f"{self.base_url}/agent/run",
            json=payload,
            timeout=timeout or self.timeout
        )
        response.raise_for_status()
        
        data = response.json()
        result = AgentResult(**data)
        
        if raise_on_error:
            result.raise_for_status()
        
        return result
    
    # Convenience methods for each agent
    
    def run_aider(
        self,
        prompt: str,
        repo_path: Optional[str] = None,
        model: str = "claude-3-5-sonnet-20241022",
        **kwargs
    ) -> AgentResult:
        """
        Run aider coding agent
        
        Args:
            prompt: Coding task
            repo_path: Repository path
            model: Claude model to use
            **kwargs: Additional arguments for run_agent()
            
        Returns:
            AgentResult
        """
        extra_args = kwargs.pop("extra_args", [])
        if model:
            extra_args = ["--model", model] + extra_args
        
        return self.run_agent(
            Agent.AIDER,
            prompt,
            repo_path=repo_path,
            extra_args=extra_args if extra_args else None,
            **kwargs
        )
    
    def run_opencode(
        self,
        prompt: str,
        repo_path: Optional[str] = None,
        **kwargs
    ) -> AgentResult:
        """
        Run opencode agent
        
        Args:
            prompt: Coding task
            repo_path: Repository path
            **kwargs: Additional arguments for run_agent()
            
        Returns:
            AgentResult
        """
        return self.run_agent(
            Agent.OPENCODE,
            prompt,
            repo_path=repo_path,
            **kwargs
        )
    
    def run_claude(
        self,
        prompt: str,
        repo_path: Optional[str] = None,
        **kwargs
    ) -> AgentResult:
        """
        Run claude-code agent
        
        Args:
            prompt: Coding task
            repo_path: Repository path
            **kwargs: Additional arguments for run_agent()
            
        Returns:
            AgentResult
        """
        return self.run_agent(
            Agent.CLAUDE,
            prompt,
            repo_path=repo_path,
            **kwargs
        )


# ═══════════════════════════════════════════════════════════════════════════
# Context Manager for Batch Operations
# ═══════════════════════════════════════════════════════════════════════════

class AgentSession:
    """
    Context manager for running multiple agent tasks
    
    Example:
        >>> with AgentSession(api_key="your-key", repo="/path/to/repo") as session:
        ...     session.run("Add error handling")
        ...     session.run("Add tests")
        ...     session.run("Add documentation")
    """
    
    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: str = "http://localhost:8000",
        repo_path: Optional[str] = None,
        agent: Agent = Agent.AIDER
    ):
        self.client = AgentVMClient(base_url=base_url, api_key=api_key)
        self.repo_path = repo_path
        self.agent = agent
        self.results: List[AgentResult] = []
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        # Print summary
        successes = sum(1 for r in self.results if r.success)
        print(f"\n{'='*60}")
        print(f"Session Summary: {successes}/{len(self.results)} tasks succeeded")
        print(f"{'='*60}")
        return False
    
    def run(
        self,
        prompt: str,
        raise_on_error: bool = False,
        **kwargs
    ) -> AgentResult:
        """Run a task in this session"""
        result = self.client.run_agent(
            self.agent,
            prompt,
            repo_path=self.repo_path,
            raise_on_error=raise_on_error,
            **kwargs
        )
        self.results.append(result)
        
        # Print immediate feedback
        status = "✓" if result.success else "✗"
        print(f"{status} {prompt[:50]}...")
        
        return result


# ═══════════════════════════════════════════════════════════════════════════
# CLI Interface
# ═══════════════════════════════════════════════════════════════════════════

def main():
    """Simple CLI for testing the client"""
    import argparse
    import os
    
    parser = argparse.ArgumentParser(description="Oligarchy AgentVM Client")
    parser.add_argument("prompt", help="Coding task prompt")
    parser.add_argument(
        "--agent",
        choices=["aider", "opencode", "claude"],
        default="aider",
        help="Agent to use"
    )
    parser.add_argument(
        "--repo",
        help="Repository path (default: /mnt/host-projects/current)"
    )
    parser.add_argument(
        "--api-key",
        default=os.getenv("AGENT_VM_API_KEY", "dev-key-2026"),
        help="API key (or set AGENT_VM_API_KEY env var)"
    )
    parser.add_argument(
        "--base-url",
        default="http://localhost:8000",
        help="API base URL"
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=600,
        help="Timeout in seconds"
    )
    
    args = parser.parse_args()
    
    if not args.api_key:
        parser.error("API key required (--api-key or AGENT_VM_API_KEY env var)")
    
    # Create client
    client = AgentVMClient(
        base_url=args.base_url,
        api_key=args.api_key,
        timeout=args.timeout
    )
    
    # Health check
    try:
        health = client.health_check()
        print(f"✓ API healthy: {health}")
    except Exception as e:
        print(f"✗ API health check failed: {e}")
        return 1
    
    # Run agent
    print(f"\nRunning {args.agent} with prompt: {args.prompt}")
    print("=" * 60)
    
    try:
        result = client.run_agent(
            Agent(args.agent),
            args.prompt,
            repo_path=args.repo,
            raise_on_error=True
        )
        
        print("\n✓ SUCCESS")
        if result.stdout:
            print("\nOutput:")
            print(result.stdout)
        
        return 0
        
    except AgentExecutionError as e:
        print("\n✗ FAILED")
        if e.result.stderr:
            print("\nError:")
            print(e.result.stderr)
        if e.result.error:
            print(f"\nException: {e.result.error}")
        return 1
    
    except Exception as e:
        print(f"\n✗ Request failed: {e}")
        return 1


if __name__ == "__main__":
    exit(main())
