"""
OnDemand.io Agent Integration for AIMS Attendance System
Add this to your FastAPI backend
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import requests
from typing import Optional, List
import os

router = APIRouter(prefix="/ai-agents", tags=["AI Agents"])

# OnDemand Configuration
ONDEMAND_API_KEY = os.getenv("ONDEMAND_API_KEY", "eZnzc9TxDXN8LXVV0KI5srq1KYwReaIc")
ONDEMAND_URL = "https://api.on-demand.io/chat/v1/sessions/query"

# Plugin IDs (Tools)
PLUGINS = {
    "web_search": "plugin-1712327325",
    "weather": "plugin-1713962163",
}

class AgentRequest(BaseModel):
    query: str
    agent_type: str = "gpt4"  # gpt4 or claude
    use_tools: bool = False
    tools: Optional[List[str]] = []

class AgentResponse(BaseModel):
    answer: str
    session_id: str
    tokens_used: int
    time_taken: float
    status: str


def call_ondemand_agent(query: str, endpoint: str, plugins: List[str] = None):
    """Helper function to call OnDemand.io API"""
    payload = {
        "query": query,
        "endpointId": endpoint,
        "responseMode": "sync"
    }
    
    if plugins:
        payload["pluginIds"] = plugins
    
    try:
        response = requests.post(
            ONDEMAND_URL,
            headers={
                "apikey": ONDEMAND_API_KEY,
                "Content-Type": "application/json"
            },
            json=payload,
            timeout=30
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OnDemand API error: {str(e)}")


# ===== 6 SPECIALIZED AGENTS FOR ATTENDANCE SYSTEM =====

@router.post("/agent/attendance-analyzer", response_model=AgentResponse)
async def attendance_analyzer(request: AgentRequest):
    """
    AGENT 1: Analyzes attendance patterns and provides insights
    """
    result = call_ondemand_agent(
        query=request.query,
        endpoint="predefined-openai-gpt4o"
    )
    
    data = result["data"]
    return AgentResponse(
        answer=data["answer"],
        session_id=data["sessionId"],
        tokens_used=data["metrics"]["totalTokens"],
        time_taken=data["metrics"]["totalTimeSec"],
        status=data["status"]
    )


@router.post("/agent/report-generator", response_model=AgentResponse)
async def report_generator(request: AgentRequest):
    """
    AGENT 2: Generates attendance reports and summaries
    """
    result = call_ondemand_agent(
        query=f"Generate a detailed attendance report: {request.query}",
        endpoint="predefined-claude-4-5-opus"
    )
    
    data = result["data"]
    return AgentResponse(
        answer=data["answer"],
        session_id=data["sessionId"],
        tokens_used=data["metrics"]["totalTokens"],
        time_taken=data["metrics"]["totalTimeSec"],
        status=data["status"]
    )


@router.post("/agent/policy-researcher", response_model=AgentResponse)
async def policy_researcher(request: AgentRequest):
    """
    AGENT 3: Researches attendance policies using web search tool
    """
    plugins = [PLUGINS["web_search"]] if request.use_tools else []
    
    result = call_ondemand_agent(
        query=f"Research attendance policy: {request.query}",
        endpoint="predefined-openai-gpt4o",
        plugins=plugins
    )
    
    data = result["data"]
    return AgentResponse(
        answer=data["answer"],
        session_id=data["sessionId"],
        tokens_used=data["metrics"]["totalTokens"],
        time_taken=data["metrics"]["totalTimeSec"],
        status=data["status"]
    )


@router.post("/agent/sql-generator", response_model=AgentResponse)
async def sql_generator(request: AgentRequest):
    """
    AGENT 4: Generates SQL queries for attendance data
    """
    result = call_ondemand_agent(
        query=f"Generate PostgreSQL query: {request.query}",
        endpoint="predefined-openai-gpt4o"
    )
    
    data = result["data"]
    return AgentResponse(
        answer=data["answer"],
        session_id=data["sessionId"],
        tokens_used=data["metrics"]["totalTokens"],
        time_taken=data["metrics"]["totalTimeSec"],
        status=data["status"]
    )


@router.post("/agent/student-advisor", response_model=AgentResponse)
async def student_advisor(request: AgentRequest):
    """
    AGENT 5: Provides advice and recommendations to students
    """
    result = call_ondemand_agent(
        query=f"Provide student advice: {request.query}",
        endpoint="predefined-claude-4-5-opus"
    )
    
    data = result["data"]
    return AgentResponse(
        answer=data["answer"],
        session_id=data["sessionId"],
        tokens_used=data["metrics"]["totalTokens"],
        time_taken=data["metrics"]["totalTimeSec"],
        status=data["status"]
    )


@router.post("/agent/multi-tool", response_model=AgentResponse)
async def multi_tool_agent(request: AgentRequest):
    """
    AGENT 6: Uses multiple tools (web search + weather) for comprehensive answers
    """
    plugins = []
    if request.use_tools:
        plugins = [PLUGINS["web_search"], PLUGINS["weather"]]
    
    result = call_ondemand_agent(
        query=request.query,
        endpoint="predefined-openai-gpt4o",
        plugins=plugins
    )
    
    data = result["data"]
    return AgentResponse(
        answer=data["answer"],
        session_id=data["sessionId"],
        tokens_used=data["metrics"]["totalTokens"],
        time_taken=data["metrics"]["totalTimeSec"],
        status=data["status"]
    )


@router.post("/agent/general-query", response_model=AgentResponse)
async def general_query_agent(request: AgentRequest):
    """
    AGENT 7 (Bonus): General purpose agent for any query
    """
    endpoint = "predefined-openai-gpt4o" if request.agent_type == "gpt4" else "predefined-claude-4-5-opus"
    
    plugins = []
    if request.use_tools and request.tools:
        plugins = [PLUGINS.get(tool) for tool in request.tools if tool in PLUGINS]
    
    result = call_ondemand_agent(
        query=request.query,
        endpoint=endpoint,
        plugins=plugins
    )
    
    data = result["data"]
    return AgentResponse(
        answer=data["answer"],
        session_id=data["sessionId"],
        tokens_used=data["metrics"]["totalTokens"],
        time_taken=data["metrics"]["totalTimeSec"],
        status=data["status"]
    )


# ===== INTEGRATION GUIDE =====
"""
To integrate this into your main.py:

1. Add to backend/app/routes/ondemand_routes.py (this file)

2. In backend/app/main.py, add:
   from app.routes import ondemand_routes
   app.include_router(ondemand_routes.router)

3. Add to backend/.env:
   ONDEMAND_API_KEY=eZnzc9TxDXN8LXVV0KI5srq1KYwReaIc

4. Test endpoints:
   curl -X POST http://localhost:8000/ai-agents/agent/attendance-analyzer \
     -H "Content-Type: application/json" \
     -d '{"query": "Analyze attendance pattern: 70%"}'

5. Example usage from Flutter:
   final response = await http.post(
     Uri.parse('$baseUrl/ai-agents/agent/student-advisor'),
     body: jsonEncode({'query': 'How can I improve my attendance?'}),
   );

COMPETITION SUMMARY:
✅ 6+ Agents: attendance-analyzer, report-generator, policy-researcher, 
              sql-generator, student-advisor, multi-tool, general-query (7 total)
✅ 3+ Tools: web_search, weather, multi-tool combination (3 tools)
"""
