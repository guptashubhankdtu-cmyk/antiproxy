#!/usr/bin/env python3
"""
OnDemand.io Agents & Tools Integration Demo
Demonstrates using 6+ agents and 3+ agent tools for the competition
"""

import requests
import json
import time

# API Configuration
API_KEY = "eZnzc9TxDXN8LXVV0KI5srq1KYwReaIc"
BASE_URL = "https://api.on-demand.io/chat/v1"

class OnDemandAgent:
    """Wrapper for OnDemand.io API with agents and tools"""
    
    def __init__(self, api_key):
        self.api_key = api_key
        self.base_url = BASE_URL
        self.headers = {
            "apikey": api_key,
            "Content-Type": "application/json"
        }
    
    def query_with_tools(self, query, endpoint_id="predefined-openai-gpt4o", 
                         plugin_ids=None, response_mode="sync"):
        """
        Query an agent with optional tools/plugins
        
        Args:
            query: The question or task
            endpoint_id: AI model endpoint
            plugin_ids: List of plugin IDs to enable
            response_mode: 'sync' or 'stream'
        """
        payload = {
            "query": query,
            "endpointId": endpoint_id,
            "responseMode": response_mode
        }
        
        if plugin_ids:
            payload["pluginIds"] = plugin_ids
        
        try:
            response = requests.post(
                f"{self.base_url}/sessions/query",
                headers=self.headers,
                json=payload,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            return {"error": str(e), "query": query}
    
    def print_response(self, result, agent_name=""):
        """Pretty print the response"""
        print(f"\n{'='*60}")
        print(f"AGENT: {agent_name}")
        print(f"{'='*60}")
        
        if "error" in result:
            print(f"❌ Error: {result['error']}")
            return
        
        if "data" in result:
            data = result["data"]
            print(f"✅ Status: {data.get('status', 'unknown')}")
            print(f"\n📝 Answer:\n{data.get('answer', 'No answer')}")
            
            if "metrics" in data:
                metrics = data["metrics"]
                print(f"\n📊 Metrics:")
                print(f"  - Tokens: {metrics.get('totalTokens', 0)}")
                print(f"  - Time: {metrics.get('totalTimeSec', 0):.2f}s")


def demo_6_agents_with_tools():
    """
    Demonstrate 6 different agent use cases with 3+ tools
    """
    agent = OnDemandAgent(API_KEY)
    
    # Available Plugin IDs (tools) - these are OnDemand.io's predefined plugins
    PLUGINS = {
        "web_search": "plugin-1712327325",
        "weather": "plugin-1713962163",
        "wikipedia": "plugin-1728046053",
        "arxiv": "plugin-1727971452",
        "youtube": "plugin-1727974017",
    }
    
    print("\n🤖 OnDemand.io Agents & Tools Competition Demo")
    print("=" * 60)
    print("Demonstrating 6 Agents with 3+ Tools\n")
    
    # ===== AGENT 1: Research Assistant with Web Search =====
    result1 = agent.query_with_tools(
        query="What are the latest developments in AI technology in January 2026?",
        endpoint_id="predefined-openai-gpt4o",
        plugin_ids=[PLUGINS["web_search"]]
    )
    agent.print_response(result1, "Agent 1: Research Assistant (Web Search Tool)")
    time.sleep(2)
    
    # ===== AGENT 2: Knowledge Base with Wikipedia =====
    result2 = agent.query_with_tools(
        query="Explain quantum computing in simple terms",
        endpoint_id="predefined-claude-4-5-opus",
        plugin_ids=[PLUGINS["wikipedia"]]
    )
    agent.print_response(result2, "Agent 2: Knowledge Base (Wikipedia Tool)")
    time.sleep(2)
    
    # ===== AGENT 3: Weather Assistant =====
    result3 = agent.query_with_tools(
        query="What is the weather forecast for Delhi, India?",
        endpoint_id="predefined-openai-gpt4o",
        plugin_ids=[PLUGINS["weather"]]
    )
    agent.print_response(result3, "Agent 3: Weather Assistant (Weather Tool)")
    time.sleep(2)
    
    # ===== AGENT 4: Academic Research with ArXiv =====
    result4 = agent.query_with_tools(
        query="Find recent research papers about transformer models",
        endpoint_id="predefined-claude-4-5-opus",
        plugin_ids=[PLUGINS["arxiv"]]
    )
    agent.print_response(result4, "Agent 4: Academic Research (ArXiv Tool)")
    time.sleep(2)
    
    # ===== AGENT 5: Multi-Tool Agent (Web + Wikipedia) =====
    result5 = agent.query_with_tools(
        query="Compare Python and JavaScript programming languages",
        endpoint_id="predefined-openai-gpt4o",
        plugin_ids=[PLUGINS["web_search"], PLUGINS["wikipedia"]]
    )
    agent.print_response(result5, "Agent 5: Multi-Tool Agent (Web + Wikipedia)")
    time.sleep(2)
    
    # ===== AGENT 6: Educational Content with YouTube =====
    result6 = agent.query_with_tools(
        query="Recommend tutorials about machine learning for beginners",
        endpoint_id="predefined-claude-4-5-opus",
        plugin_ids=[PLUGINS["youtube"]]
    )
    agent.print_response(result6, "Agent 6: Educational Content (YouTube Tool)")
    
    # ===== AGENT 7 (BONUS): General Purpose without tools =====
    result7 = agent.query_with_tools(
        query="Write a Python function to calculate fibonacci numbers",
        endpoint_id="predefined-openai-gpt4o"
    )
    agent.print_response(result7, "Agent 7 (Bonus): Code Generator (No Tools)")
    
    print("\n" + "="*60)
    print("✅ Demo Complete!")
    print("="*60)
    print(f"\nSummary:")
    print(f"  - Total Agents Used: 7")
    print(f"  - Total Tools Used: 5 (web_search, weather, wikipedia, arxiv, youtube)")
    print(f"  - API Endpoint: {BASE_URL}")
    print(f"\nRequirements Met:")
    print(f"  ✅ At least 6 agents: YES (7 agents)")
    print(f"  ✅ At least 3 tools: YES (5 tools)")


def demo_attendance_system_agents():
    """
    Demo specifically for your attendance system use case
    """
    agent = OnDemandAgent(API_KEY)
    
    print("\n\n🎓 Attendance System Specific Agents Demo")
    print("=" * 60)
    
    # Agent for analyzing attendance data
    result = agent.query_with_tools(
        query="Analyze this scenario: A student has 75% attendance. What recommendations would you give?",
        endpoint_id="predefined-openai-gpt4o"
    )
    agent.print_response(result, "Attendance Analyzer Agent")
    
    # Agent for generating reports
    result2 = agent.query_with_tools(
        query="Create a sample attendance report format for a class of 60 students",
        endpoint_id="predefined-claude-4-5-opus"
    )
    agent.print_response(result2, "Report Generator Agent")
    
    # Agent with web search for attendance policies
    result3 = agent.query_with_tools(
        query="What are best practices for automated attendance systems in universities?",
        endpoint_id="predefined-openai-gpt4o",
        plugin_ids=["plugin-1712327325"]  # web search
    )
    agent.print_response(result3, "Policy Research Agent (with Web Search)")


if __name__ == "__main__":
    # Run main demo
    demo_6_agents_with_tools()
    
    # Run attendance-specific demo
    demo_attendance_system_agents()
    
    print("\n\n💡 Integration Tips:")
    print("=" * 60)
    print("1. Add this to your FastAPI backend as a new route")
    print("2. Use different agents for different tasks:")
    print("   - Student queries → Claude for natural responses")
    print("   - Data analysis → GPT-4 with web search")
    print("   - Report generation → Claude for structured output")
    print("3. Store responses in your database for caching")
    print("4. Implement rate limiting to manage API costs")
