# ========================================
# HTTP API Adapter - Communicates with AgentVM API
# ========================================

import aiohttp
import asyncio
import logging
from typing import Dict, Any, Optional
from .agent_manager import APIAdapter, TaskResult

class HTTPAPIAdapter(APIAdapter):
    """HTTP-based adapter for AgentVM API communication"""
    
    def __init__(self, api_endpoint: str, api_key: str, timeout: int = 30):
        self.api_endpoint = api_endpoint.rstrip('/')
        self.api_key = api_key
        self.timeout = timeout
        self.session: Optional[aiohttp.ClientSession] = None
        self.logger = logging.getLogger(__name__)
        
        # Connection state
        self._connected = False
        self._connection_check_task: Optional[asyncio.Task] = None
    
    async def initialize(self) -> bool:
        """Initialize the HTTP adapter"""
        try:
            # Create HTTP session
            self.session = aiohttp.ClientSession(
                timeout=aiohttp.ClientTimeout(total=self.timeout),
                headers={
                    'User-Agent': 'AgentSystem/1.0',
                    'X-API-Key': self.api_key,
                    'Content-Type': 'application/json'
                }
            )
            
            # Test connection
            await self.test_connection()
            
            self.logger.info(f"HTTP API Adapter initialized: {self.api_endpoint}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to initialize HTTP API adapter: {e}")
            return False
    
    async def cleanup(self) -> None:
        """Clean up resources"""
        if self.session:
            await self.session.close()
            self.session = None
        
        if self._connection_check_task:
            self._connection_check_task.cancel()
            self._connection_check_task = None
    
    async def test_connection(self) -> bool:
        """Test connection to API"""
        try:
            if not self.session:
                return False
            
            url = f"{self.api_endpoint}/health"
            async with self.session.get(url) as response:
                if response.status == 200:
                    self._connected = True
                    self.logger.info("API connection successful")
                    return True
                else:
                    self._connected = False
                    self.logger.warning(f"API health check failed: {response.status}")
                    return False
                    
        except Exception as e:
            self._connected = False
            self.logger.error(f"API connection test failed: {e}")
            return False
    
    def is_connected(self) -> bool:
        """Check if API is connected"""
        return self._connected
    
    async def execute_agent(self, agent_type: str, prompt: str, **kwargs) -> TaskResult:
        """Execute agent task via HTTP API"""
        if not self.session:
            raise RuntimeError("Adapter not initialized")
        
        try:
            url = f"{self.api_endpoint}/agent/run"
            
            payload = {
                "agent": agent_type,
                "prompt": prompt,
                "timeout": kwargs.get("timeout", 600),
                "repo_path": kwargs.get("repo_path", "/app/workspace")
            }
            
            async with self.session.post(url, json=payload) as response:
                if response.status == 200:
                    data = await response.json()
                    
                    result = TaskResult(
                        task_id=kwargs.get("task_id", ""),
                        agent_id=kwargs.get("agent_id", ""),
                        success=data.get("success", False),
                        output=data.get("stdout", ""),
                        error=data.get("stderr", "")
                    )
                    
                    self.logger.info(f"Agent task executed successfully: {result.task_id}")
                    return result
                else:
                    error_text = f"HTTP {response.status}"
                    try:
                        error_data = await response.json()
                        error_text = error_data.get("error", error_text)
                    except:
                        pass
                    
                    result = TaskResult(
                        task_id=kwargs.get("task_id", ""),
                        agent_id=kwargs.get("agent_id", ""),
                        success=False,
                        error=error_text
                    )
                    
                    self.logger.error(f"Agent task failed: {error_text}")
                    return result
                    
        except Exception as e:
            error_msg = f"HTTP request failed: {str(e)}"
            self.logger.error(error_msg)
            
            return TaskResult(
                task_id=kwargs.get("task_id", ""),
                agent_id=kwargs.get("agent_id", ""),
                success=False,
                error=error_msg
            )
    
    async def get_agent_status(self, task_id: str) -> Dict[str, Any]:
        """Get status of running agent task"""
        if not self.session:
            raise RuntimeError("Adapter not initialized")
        
        try:
            url = f"{self.api_endpoint}/agent/status/{task_id}"
            
            async with self.session.get(url) as response:
                if response.status == 200:
                    data = await response.json()
                    return data
                else:
                    error_msg = f"HTTP {response.status}"
                    self.logger.error(f"Failed to get agent status: {error_msg}")
                    return {"error": error_msg}
                    
        except Exception as e:
            error_msg = f"Status check failed: {str(e)}"
            self.logger.error(error_msg)
            return {"error": error_msg}
    
    async def cancel_task(self, task_id: str) -> bool:
        """Cancel running task"""
        if not self.session:
            raise RuntimeError("Adapter not initialized")
        
        try:
            url = f"{self.api_endpoint}/agent/cancel/{task_id}"
            
            async with self.session.post(url) as response:
                if response.status == 200:
                    self.logger.info(f"Task {task_id} cancelled successfully")
                    return True
                else:
                    self.logger.error(f"Failed to cancel task {task_id}: HTTP {response.status}")
                    return False
                    
        except Exception as e:
            self.logger.error(f"Task cancellation failed: {e}")
            return False
    
    async def start_connection_monitoring(self) -> None:
        """Start background connection monitoring"""
        if self._connection_check_task:
            self._connection_check_task.cancel()
        
        async def monitor():
            while True:
                await asyncio.sleep(30)  # Check every 30 seconds
                await self.test_connection()
        
        self._connection_check_task = asyncio.create_task(monitor())
    
    async def stop_connection_monitoring(self) -> None:
        """Stop connection monitoring"""
        if self._connection_check_task:
            self._connection_check_task.cancel()
            self._connection_check_task = None

# ========================================
# WebSocket API Adapter - Real-time Communication
# ========================================

import websockets
import json

class WebSocketAPIAdapter(APIAdapter):
    """WebSocket-based adapter for real-time agent communication"""
    
    def __init__(self, websocket_url: str, api_key: str):
        self.websocket_url = websocket_url
        self.api_key = api_key
        self.websocket: Optional[websockets.WebSocketServerProtocol] = None
        self.logger = logging.getLogger(__name__)
        
        # Connection state
        self._connected = False
        self._message_handlers: Dict[str, callable] = {}
    
    async def initialize(self) -> bool:
        """Initialize WebSocket connection"""
        try:
            headers = {
                'Authorization': f'Bearer {self.api_key}',
                'User-Agent': 'AgentSystem/1.0'
            }
            
            self.websocket = await websockets.connect(
                self.websocket_url,
                extra_headers=headers
            )
            
            self._connected = True
            self.logger.info(f"WebSocket connected: {self.websocket_url}")
            
            # Start message listener
            asyncio.create_task(self._message_listener())
            
            return True
            
        except Exception as e:
            self.logger.error(f"WebSocket connection failed: {e}")
            return False
    
    async def cleanup(self) -> None:
        """Clean up WebSocket connection"""
        if self.websocket:
            await self.websocket.close()
            self.websocket = None
        
        self._connected = False
    
    def is_connected(self) -> bool:
        """Check if WebSocket is connected"""
        return self._connected
    
    async def execute_agent(self, agent_type: str, prompt: str, **kwargs) -> TaskResult:
        """Execute agent task via WebSocket"""
        if not self.websocket:
            raise RuntimeError("WebSocket not connected")
        
        try:
            task_id = kwargs.get("task_id", "")
            
            # Send task execution request
            message = {
                "type": "execute_agent",
                "data": {
                    "task_id": task_id,
                    "agent_type": agent_type,
                    "prompt": prompt,
                    "timeout": kwargs.get("timeout", 600),
                    "repo_path": kwargs.get("repo_path", "/app/workspace")
                }
            }
            
            await self.websocket.send(json.dumps(message))
            
            # Wait for response (simplified - in production, use proper async handling)
            result_data = await self._wait_for_response(task_id, timeout=kwargs.get("timeout", 600))
            
            if result_data:
                return TaskResult(
                    task_id=task_id,
                    agent_id=kwargs.get("agent_id", ""),
                    success=result_data.get("success", False),
                    output=result_data.get("output", ""),
                    error=result_data.get("error", "")
                )
            else:
                return TaskResult(
                    task_id=task_id,
                    agent_id=kwargs.get("agent_id", ""),
                    success=False,
                    error="Timeout waiting for response"
                )
                
        except Exception as e:
            error_msg = f"WebSocket task execution failed: {str(e)}"
            self.logger.error(error_msg)
            
            return TaskResult(
                task_id=kwargs.get("task_id", ""),
                agent_id=kwargs.get("agent_id", ""),
                success=False,
                error=error_msg
            )
    
    async def get_agent_status(self, task_id: str) -> Dict[str, Any]:
        """Get status via WebSocket"""
        # Send status request
        message = {
            "type": "get_status",
            "data": {"task_id": task_id}
        }
        
        await self.websocket.send(json.dumps(message))
        
        # Wait for status response
        status_data = await self._wait_for_response(f"status_{task_id}", timeout=10)
        
        return status_data or {"error": "No response received"}
    
    async def cancel_task(self, task_id: str) -> bool:
        """Cancel task via WebSocket"""
        try:
            message = {
                "type": "cancel_task",
                "data": {"task_id": task_id}
            }
            
            await self.websocket.send(json.dumps(message))
            
            # Wait for cancellation confirmation
            response = await self._wait_for_response(f"cancel_{task_id}", timeout=30)
            
            return response.get("success", False) if response else False
            
        except Exception as e:
            self.logger.error(f"WebSocket task cancellation failed: {e}")
            return False
    
    async def _message_listener(self) -> None:
        """Listen for WebSocket messages"""
        try:
            async for message in self.websocket:
                try:
                    data = json.loads(message)
                    await self._handle_message(data)
                except json.JSONDecodeError as e:
                    self.logger.error(f"Failed to decode WebSocket message: {e}")
                    
        except websockets.exceptions.ConnectionClosed:
            self._connected = False
            self.logger.info("WebSocket connection closed")
        except Exception as e:
            self.logger.error(f"WebSocket listener error: {e}")
    
    async def _handle_message(self, data: Dict[str, Any]) -> None:
        """Handle incoming WebSocket message"""
        message_type = data.get("type")
        message_data = data.get("data", {})
        
        if message_type == "task_result":
            task_id = message_data.get("task_id")
            if task_id in self._message_handlers:
                self._message_handlers[task_id](message_data)
                del self._message_handlers[task_id]
        elif message_type == "status_update":
            # Handle status updates
            pass
        elif message_type == "connection_status":
            self._connected = message_data.get("connected", False)
    
    async def _wait_for_response(self, response_key: str, timeout: int = 600) -> Optional[Dict[str, Any]]:
        """Wait for specific response with timeout"""
        response_received = asyncio.Event()
        
        # Store handler for this response
        def handler(data):
            response_received.data = data
            response_received.set()
        
        self._message_handlers[response_key] = handler
        
        try:
            # Wait for response with timeout
            await asyncio.wait_for(response_received.wait(), timeout=timeout)
            
            # Return the response data
            return getattr(response_received, 'data', None)
            
        except asyncio.TimeoutError:
            self.logger.warning(f"Timeout waiting for response: {response_key}")
            return None
        finally:
            # Clean up handler
            if response_key in self._message_handlers:
                del self._message_handlers[response_key]