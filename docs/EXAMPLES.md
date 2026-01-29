# Oligarchy AgentVM - Usage Examples

Comprehensive examples for common workflows and integrations.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Python Integration](#python-integration)
- [Shell Scripts](#shell-scripts)
- [Game Engine Integration](#game-engine-integration)
- [Workflow Automation](#workflow-automation)
- [Advanced Patterns](#advanced-patterns)

---

## Basic Usage

### Starting and Connecting

```bash
# Build VM image (first time only)
nix build .#agent-vm-qcow2

# Launch VM
nix run .#run &

# Wait for boot (takes ~10-15 seconds)
sleep 15

# Connect via SSH
ssh user@127.0.0.1 -p 2222
# Default password: "agent" (change on first login)
```

### Quick API Test

```bash
# Health check
curl http://localhost:8000/health

# Run aider with minimal prompt
curl -X POST http://localhost:8000/agent/run \
  -H "X-API-Key: dev-key-2026" \
  -H "Content-Type: application/json" \
  -d '{
    "agent": "aider",
    "prompt": "Add type hints to all functions in utils.py",
    "repo_path": "/mnt/host-projects/my-app"
  }'
```

### Inside VM Session

```bash
# SSH in (drops into unique tmux session)
ssh user@127.0.0.1 -p 2222

# Navigate to shared host directory
cd /mnt/host-projects/my-project

# Use Neovim with LSP
vim flake.nix
# Press <space>ff to find files
# Press <space>fg to grep
# Press gd on a symbol to go to definition

# Run agents directly
aider --model claude-3-5-sonnet-20241022 \
      --message "Refactor the database module"

# Use the quest alias for quick API testing
quest '{"agent":"aider","prompt":"Add tests"}' \
  http://localhost:8000/agent/run
```

---

## Python Integration

### Basic Client Usage

```python
from agent_vm_client import AgentVMClient

# Create client
client = AgentVMClient(
    base_url="http://localhost:8000",
    api_key="your-api-key-here"
)

# Run aider
result = client.run_aider(
    prompt="Add error handling to the API endpoints",
    repo_path="/mnt/host-projects/backend"
)

if result.success:
    print("✓ Changes applied:")
    print(result.stdout)
else:
    print("✗ Failed:")
    print(result.stderr or result.error)
```

### Batch Operations

```python
from agent_vm_client import AgentSession, Agent

# Run multiple tasks in sequence
with AgentSession(
    api_key="your-key",
    repo_path="/mnt/host-projects/backend",
    agent=Agent.AIDER
) as session:
    
    # Each task runs sequentially
    session.run("Add comprehensive error handling")
    session.run("Add input validation to all endpoints")
    session.run("Add rate limiting middleware")
    session.run("Add request/response logging")
    session.run("Update API documentation")

# Prints summary at end:
# Session Summary: 5/5 tasks succeeded
```

### Error Handling

```python
from agent_vm_client import AgentVMClient, AgentExecutionError, Agent

client = AgentVMClient(api_key="your-key")

try:
    result = client.run_agent(
        Agent.AIDER,
        prompt="Implement the new feature",
        raise_on_error=True  # Raise exception on failure
    )
    print(f"Success! Modified files:")
    print(result.stdout)
    
except AgentExecutionError as e:
    print(f"Agent failed: {e}")
    print(f"Return code: {e.result.returncode}")
    print(f"Error output: {e.result.stderr}")
    
except Exception as e:
    print(f"API request failed: {e}")
```

### Custom Timeout and Arguments

```python
# Long-running task with custom timeout
result = client.run_aider(
    prompt="Refactor the entire authentication system",
    timeout=1800,  # 30 minutes
    extra_args=[
        "--yes-always",  # Auto-accept all changes
        "--no-auto-commits"  # Don't auto-commit
    ]
)

# Different model
result = client.run_aider(
    prompt="Quick fix",
    model="claude-3-5-haiku-20241022"  # Faster, cheaper
)
```

---

## Shell Scripts

### Automated Code Review Script

```bash
#!/bin/bash
# code-review.sh - Run AI code review on changed files

set -euo pipefail

API_KEY="${AGENT_VM_API_KEY:-dev-key-2026}"
API_URL="http://localhost:8000"
REPO_PATH="${1:-/mnt/host-projects/current}"

# Get list of modified files
MODIFIED_FILES=$(cd "$REPO_PATH" && git diff --name-only HEAD)

if [ -z "$MODIFIED_FILES" ]; then
    echo "No modified files to review"
    exit 0
fi

echo "🔍 Reviewing modified files:"
echo "$MODIFIED_FILES"
echo ""

# Run aider to review changes
PROMPT="Review the following modified files and suggest improvements:
$MODIFIED_FILES

Focus on:
- Code quality and maintainability
- Potential bugs or edge cases
- Performance considerations
- Security issues"

curl -X POST "$API_URL/agent/run" \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
        --arg agent "aider" \
        --arg prompt "$PROMPT" \
        --arg repo "$REPO_PATH" \
        '{agent: $agent, prompt: $prompt, repo_path: $repo, timeout: 300}'
    )" | jq -r '
        if .success then
            "✓ Review complete\n\n\(.stdout)"
        else
            "✗ Review failed\n\n\(.stderr // .error)"
        end
    '
```

### Parallel Task Runner

```bash
#!/bin/bash
# parallel-tasks.sh - Run multiple independent agent tasks in parallel

API_KEY="${AGENT_VM_API_KEY}"
API_URL="http://localhost:8000"
REPO_PATH="/mnt/host-projects/my-app"

# Define tasks
declare -a TASKS=(
    "Add comprehensive docstrings to all functions in utils.py"
    "Add error handling to all database operations"
    "Update tests to cover edge cases"
    "Optimize database queries for performance"
)

# Function to run a single task
run_task() {
    local prompt="$1"
    local task_id="$2"
    
    echo "[Task $task_id] Starting: $prompt"
    
    result=$(curl -s -X POST "$API_URL/agent/run" \
        -H "X-API-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$(jq -n \
            --arg agent "aider" \
            --arg prompt "$prompt" \
            --arg repo "$REPO_PATH" \
            '{agent: $agent, prompt: $prompt, repo_path: $repo}'
        )")
    
    if echo "$result" | jq -e '.success' > /dev/null; then
        echo "[Task $task_id] ✓ Complete"
    else
        echo "[Task $task_id] ✗ Failed"
        echo "$result" | jq -r '.error // .stderr'
    fi
}

# Export function and variables for parallel
export -f run_task
export API_KEY API_URL REPO_PATH

# Run tasks in parallel (max 4 at once)
printf '%s\n' "${TASKS[@]}" | \
    parallel -j 4 --line-buffer run_task {} {#}
```

### Daily Maintenance Script

```bash
#!/bin/bash
# daily-maintenance.sh - Run daily code maintenance tasks

set -euo pipefail

REPO_PATH="/mnt/host-projects/main-app"
API_KEY="$AGENT_VM_API_KEY"

echo "🔧 Daily Maintenance - $(date)"
echo "================================"

# Task 1: Update dependencies
echo "→ Checking dependency updates..."
curl -X POST http://localhost:8000/agent/run \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "agent": "aider",
        "prompt": "Check for outdated dependencies and suggest safe updates",
        "repo_path": "'$REPO_PATH'"
    }' > /tmp/deps.json

if jq -e '.success' /tmp/deps.json > /dev/null; then
    echo "✓ Dependency check complete"
else
    echo "✗ Dependency check failed"
fi

# Task 2: Code cleanup
echo "→ Running code cleanup..."
curl -X POST http://localhost:8000/agent/run \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "agent": "aider",
        "prompt": "Remove unused imports, fix linting issues, improve code formatting",
        "repo_path": "'$REPO_PATH'"
    }' > /tmp/cleanup.json

if jq -e '.success' /tmp/cleanup.json > /dev/null; then
    echo "✓ Code cleanup complete"
else
    echo "✗ Code cleanup failed"
fi

# Task 3: Documentation sync
echo "→ Syncing documentation..."
curl -X POST http://localhost:8000/agent/run \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "agent": "aider",
        "prompt": "Update README and API docs to match current code",
        "repo_path": "'$REPO_PATH'"
    }' > /tmp/docs.json

if jq -e '.success' /tmp/docs.json > /dev/null; then
    echo "✓ Documentation sync complete"
else
    echo "✗ Documentation sync failed"
fi

echo ""
echo "================================"
echo "Maintenance complete!"
```

---

## Game Engine Integration

### Unity C# Example

```csharp
using UnityEngine;
using UnityEngine.Networking;
using System.Collections;
using System.Collections.Generic;
using Newtonsoft.Json;

public class AgentVMController : MonoBehaviour
{
    [SerializeField] private string apiUrl = "http://localhost:8000";
    [SerializeField] private string apiKey = "your-api-key";
    
    [System.Serializable]
    public class AgentRequest
    {
        public string agent;
        public string prompt;
        public string repo_path;
        public int timeout = 600;
    }
    
    [System.Serializable]
    public class AgentResponse
    {
        public bool success;
        public string stdout;
        public string stderr;
        public string error;
    }
    
    public void RunCodingQuest(string objective, string repoPath = "/mnt/host-projects/game-code")
    {
        StartCoroutine(RunAgentCoroutine(objective, repoPath));
    }
    
    private IEnumerator RunAgentCoroutine(string prompt, string repoPath)
    {
        var request = new AgentRequest
        {
            agent = "aider",
            prompt = prompt,
            repo_path = repoPath
        };
        
        string json = JsonConvert.SerializeObject(request);
        byte[] bodyRaw = System.Text.Encoding.UTF8.GetBytes(json);
        
        using (UnityWebRequest www = new UnityWebRequest($"{apiUrl}/agent/run", "POST"))
        {
            www.uploadHandler = new UploadHandlerRaw(bodyRaw);
            www.downloadHandler = new DownloadHandlerBuffer();
            www.SetRequestHeader("Content-Type", "application/json");
            www.SetRequestHeader("X-API-Key", apiKey);
            
            yield return www.SendWebRequest();
            
            if (www.result == UnityWebRequest.Result.Success)
            {
                var response = JsonConvert.DeserializeObject<AgentResponse>(www.downloadHandler.text);
                
                if (response.success)
                {
                    Debug.Log($"Quest completed! Output: {response.stdout}");
                    OnQuestCompleted(response);
                }
                else
                {
                    Debug.LogError($"Quest failed: {response.error ?? response.stderr}");
                    OnQuestFailed(response);
                }
            }
            else
            {
                Debug.LogError($"API request failed: {www.error}");
            }
        }
    }
    
    private void OnQuestCompleted(AgentResponse response)
    {
        // Award player XP, unlock next quest, etc.
        // Parse response.stdout for what was changed
    }
    
    private void OnQuestFailed(AgentResponse response)
    {
        // Show error to player, allow retry, etc.
    }
}

// Usage in game:
// GetComponent<AgentVMController>().RunCodingQuest(
//     "Add a new enemy type with ranged attacks"
// );
```

### Godot GDScript Example

```gdscript
extends Node
class_name AgentVMClient

const API_URL = "http://localhost:8000"
var api_key: String = ""

func _init(key: String = ""):
    api_key = key

func run_coding_quest(objective: String, repo_path: String = "/mnt/host-projects/game") -> void:
    var http_request = HTTPRequest.new()
    add_child(http_request)
    http_request.request_completed.connect(_on_quest_completed)
    
    var headers = [
        "X-API-Key: " + api_key,
        "Content-Type: application/json"
    ]
    
    var body = JSON.stringify({
        "agent": "aider",
        "prompt": objective,
        "repo_path": repo_path,
        "timeout": 600
    })
    
    var error = http_request.request(API_URL + "/agent/run", headers, HTTPClient.METHOD_POST, body)
    
    if error != OK:
        push_error("Failed to send quest request: " + str(error))

func _on_quest_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if response_code != 200:
        push_error("Quest failed with code: " + str(response_code))
        return
    
    var json = JSON.parse_string(body.get_string_from_utf8())
    
    if json.success:
        print("✓ Quest completed!")
        print("Changes: ", json.stdout)
        emit_signal("quest_completed", json)
    else:
        print("✗ Quest failed!")
        print("Error: ", json.error if json.error else json.stderr)
        emit_signal("quest_failed", json)

signal quest_completed(result: Dictionary)
signal quest_failed(result: Dictionary)

# Usage in game:
# var agent = AgentVMClient.new("your-api-key")
# add_child(agent)
# agent.run_coding_quest("Implement player double-jump ability")
# agent.quest_completed.connect(_on_player_quest_done)
```

### Unreal Engine Blueprint Integration

For Unreal Engine, use the HTTP request nodes:

1. Add **VaRest** plugin to your project
2. Create Blueprint function:

```
[Event] RunCodingQuest
  ↓
[Construct Json Object]
  - agent: "aider"
  - prompt: [Input] Objective
  - repo_path: "/mnt/host-projects/ue-game"
  ↓
[Construct Request]
  - URL: "http://localhost:8000/agent/run"
  - Verb: POST
  - Add Header: "X-API-Key" = "your-key"
  - Set Json Object
  ↓
[Process Request]
  ↓
[On Response Received]
  ↓
[Branch] success == true
  - True → [Quest Complete] (Award XP, unlock content)
  - False → [Quest Failed] (Show error message)
```

---

## Workflow Automation

### GitHub Actions Integration

```yaml
# .github/workflows/agent-review.yml
name: AI Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  ai-review:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Review with AgentVM
        env:
          AGENT_VM_API_KEY: ${{ secrets.AGENT_VM_API_KEY }}
          AGENT_VM_URL: ${{ secrets.AGENT_VM_URL }}
        run: |
          # Get changed files
          CHANGED_FILES=$(git diff --name-only origin/main...HEAD)
          
          # Create review prompt
          PROMPT="Review these changed files for:
          - Code quality issues
          - Potential bugs
          - Security concerns
          - Performance problems
          
          Files:
          $CHANGED_FILES
          
          Provide specific feedback with line numbers."
          
          # Run review
          RESULT=$(curl -X POST "$AGENT_VM_URL/agent/run" \
            -H "X-API-Key: $AGENT_VM_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{
              \"agent\": \"aider\",
              \"prompt\": \"$PROMPT\",
              \"repo_path\": \"$GITHUB_WORKSPACE\",
              \"timeout\": 600
            }")
          
          # Post as comment
          echo "$RESULT" | jq -r '.stdout' > review.md
          gh pr comment ${{ github.event.pull_request.number }} \
            --body-file review.md
```

### Jenkins Pipeline

```groovy
// Jenkinsfile
pipeline {
    agent any
    
    environment {
        AGENT_VM_URL = 'http://agent-vm.internal:8000'
        AGENT_VM_KEY = credentials('agent-vm-api-key')
    }
    
    stages {
        stage('AI Code Review') {
            steps {
                script {
                    def response = sh(
                        script: """
                            curl -X POST ${AGENT_VM_URL}/agent/run \
                                -H "X-API-Key: ${AGENT_VM_KEY}" \
                                -H "Content-Type: application/json" \
                                -d '{
                                    "agent": "aider",
                                    "prompt": "Review recent changes for quality issues",
                                    "repo_path": "${WORKSPACE}",
                                    "timeout": 600
                                }'
                        """,
                        returnStdout: true
                    ).trim()
                    
                    def result = readJSON text: response
                    
                    if (result.success) {
                        echo "✓ Review passed"
                        echo result.stdout
                    } else {
                        error "✗ Review failed: ${result.error}"
                    }
                }
            }
        }
        
        stage('AI Test Generation') {
            steps {
                script {
                    sh """
                        curl -X POST ${AGENT_VM_URL}/agent/run \
                            -H "X-API-Key: ${AGENT_VM_KEY}" \
                            -H "Content-Type: application/json" \
                            -d '{
                                "agent": "aider",
                                "prompt": "Generate tests for any untested code",
                                "repo_path": "${WORKSPACE}",
                                "timeout": 900
                            }'
                    """
                }
            }
        }
    }
}
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit
# Run AI code review before commit

API_KEY="${AGENT_VM_API_KEY}"
API_URL="${AGENT_VM_URL:-http://localhost:8000}"

# Get staged files
STAGED=$(git diff --cached --name-only)

if [ -z "$STAGED" ]; then
    exit 0
fi

echo "🤖 Running AI pre-commit review..."

PROMPT="Review these staged files before commit:
$STAGED

Check for:
- Syntax errors
- Common mistakes
- Unintentional debug code
- Missing error handling"

RESULT=$(curl -s -X POST "$API_URL/agent/run" \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
        --arg agent "aider" \
        --arg prompt "$PROMPT" \
        --arg repo "$(pwd)" \
        '{agent: $agent, prompt: $prompt, repo_path: $repo, timeout: 120}'
    )")

SUCCESS=$(echo "$RESULT" | jq -r '.success')

if [ "$SUCCESS" = "true" ]; then
    echo "✓ Pre-commit review passed"
    exit 0
else
    echo "✗ Pre-commit review found issues:"
    echo "$RESULT" | jq -r '.stderr // .error'
    echo ""
    echo "Commit anyway? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        exit 0
    else
        exit 1
    fi
fi
```

---

## Advanced Patterns

### Multi-Agent Collaboration

```python
from agent_vm_client import AgentVMClient, Agent

client = AgentVMClient(api_key="your-key")
repo = "/mnt/host-projects/complex-app"

# Step 1: Aider implements feature
print("Phase 1: Implementation...")
impl_result = client.run_agent(
    Agent.AIDER,
    "Implement user authentication with JWT tokens",
    repo_path=repo,
    timeout=900
)

if not impl_result.success:
    print("Implementation failed, aborting")
    exit(1)

# Step 2: OpenCode reviews and optimizes
print("Phase 2: Review and optimization...")
review_result = client.run_agent(
    Agent.OPENCODE,
    "Review the JWT authentication implementation and optimize for security and performance",
    repo_path=repo,
    timeout=600
)

# Step 3: Aider adds tests
print("Phase 3: Test generation...")
test_result = client.run_agent(
    Agent.AIDER,
    "Generate comprehensive tests for the authentication module, including edge cases",
    repo_path=repo,
    timeout=600
)

# Step 4: Claude Code adds documentation
print("Phase 4: Documentation...")
docs_result = client.run_agent(
    Agent.CLAUDE,
    "Add detailed documentation for the authentication system, including usage examples",
    repo_path=repo,
    timeout=300
)

# Summary
print("\n" + "="*60)
print("Multi-agent workflow complete:")
print(f"  Implementation: {'✓' if impl_result.success else '✗'}")
print(f"  Review:         {'✓' if review_result.success else '✗'}")
print(f"  Tests:          {'✓' if test_result.success else '✗'}")
print(f"  Documentation:  {'✓' if docs_result.success else '✗'}")
```

### Continuous Improvement Loop

```python
import time
from agent_vm_client import AgentVMClient

def continuous_improvement(repo_path, interval_minutes=30):
    """
    Run continuous code improvement in the background
    """
    client = AgentVMClient(api_key="your-key")
    
    tasks = [
        "Improve code documentation",
        "Optimize database queries",
        "Add error handling",
        "Improve type hints",
        "Refactor complex functions",
        "Add missing tests",
        "Update dependencies",
        "Fix linting issues"
    ]
    
    task_index = 0
    
    while True:
        task = tasks[task_index % len(tasks)]
        print(f"\n[{time.strftime('%Y-%m-%d %H:%M:%S')}] Running: {task}")
        
        result = client.run_aider(
            prompt=task,
            repo_path=repo_path,
            timeout=600
        )
        
        if result.success:
            print(f"✓ Completed: {task}")
        else:
            print(f"✗ Failed: {task}")
        
        task_index += 1
        time.sleep(interval_minutes * 60)

# Run in background
if __name__ == "__main__":
    continuous_improvement("/mnt/host-projects/main-app", interval_minutes=30)
```

### Quest System for Gamified Development

```python
from dataclasses import dataclass
from typing import List
from agent_vm_client import AgentVMClient, AgentResult

@dataclass
class Quest:
    """A coding quest that awards XP"""
    id: str
    title: str
    description: str
    prompt: str
    xp_reward: int
    difficulty: str  # "easy", "medium", "hard"

class QuestSystem:
    """Gamification layer over AgentVM"""
    
    def __init__(self, api_key: str, repo_path: str):
        self.client = AgentVMClient(api_key=api_key)
        self.repo_path = repo_path
        self.completed_quests = []
        self.total_xp = 0
    
    def attempt_quest(self, quest: Quest) -> tuple[bool, AgentResult]:
        """Attempt to complete a quest"""
        print(f"\n🎯 Quest: {quest.title}")
        print(f"   Difficulty: {quest.difficulty}")
        print(f"   Reward: {quest.xp_reward} XP")
        print(f"   {quest.description}")
        print()
        
        result = self.client.run_aider(
            prompt=quest.prompt,
            repo_path=self.repo_path,
            timeout=900
        )
        
        if result.success:
            self.completed_quests.append(quest.id)
            self.total_xp += quest.xp_reward
            print(f"✓ Quest completed! +{quest.xp_reward} XP")
            print(f"   Total XP: {self.total_xp}")
            return True, result
        else:
            print(f"✗ Quest failed!")
            return False, result
    
    def get_level(self) -> int:
        """Calculate player level from XP"""
        return int((self.total_xp / 100) ** 0.5) + 1

# Example quests
QUESTS = [
    Quest(
        id="quest_001",
        title="The Docstring Quest",
        description="Add docstrings to all undocumented functions",
        prompt="Add comprehensive docstrings to all functions missing them",
        xp_reward=100,
        difficulty="easy"
    ),
    Quest(
        id="quest_002",
        title="Guardian of Errors",
        description="Protect the codebase with error handling",
        prompt="Add try-except blocks and error handling to all risky operations",
        xp_reward=200,
        difficulty="medium"
    ),
    Quest(
        id="quest_003",
        title="The Great Refactoring",
        description="Simplify complex code for better maintainability",
        prompt="Refactor functions with cyclomatic complexity > 10",
        xp_reward=300,
        difficulty="hard"
    ),
]

# Run quest system
if __name__ == "__main__":
    system = QuestSystem(
        api_key="your-key",
        repo_path="/mnt/host-projects/game"
    )
    
    for quest in QUESTS:
        success, result = system.attempt_quest(quest)
        if not success:
            print("Quest failed, try again later...")
            break
    
    print(f"\n🏆 Final Level: {system.get_level()}")
    print(f"   Total XP: {system.total_xp}")
```

---

## Notes

- All examples assume the VM is running and accessible at `localhost:8000`
- Replace `your-api-key` with your actual API key
- Repository paths should match your VM's virtiofs mount configuration
- Adjust timeouts based on task complexity
- For production, always use `apiKeyFile` instead of hardcoded keys

For more examples, see the [README](README.md) and [flake.nix](flake.nix) documentation.
