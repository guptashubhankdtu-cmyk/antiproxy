#!/usr/bin/env python3
"""
Demo: Using OnDemand.io PRESET AGENTS (not just chat queries)
This shows the difference between basic chat and preset agents with tools
"""

import requests
import json

API_KEY = "eZnzc9TxDXN8LXVV0KI5srq1KYwReaIc"

# ===== METHOD 1: Basic Chat Query (what we used before) =====
def basic_chat_query(query):
    """Basic chat query - no preset agent"""
    print("\n" + "="*70)
    print("METHOD 1: Basic Chat Query (Simple)")
    print("="*70)
    
    response = requests.post(
        "https://api.on-demand.io/chat/v1/sessions/query",
        headers={
            "apikey": API_KEY,
            "Content-Type": "application/json"
        },
        json={
            "query": query,
            "endpointId": "predefined-openai-gpt4o",
            "responseMode": "sync"
        }
    )
    
    result = response.json()
    print(f"Query: {query}")
    print(f"Answer: {result['data']['answer'][:200]}...")
    print(f"Tokens: {result['data']['metrics']['totalTokens']}")


# ===== METHOD 2: Using PRESET AGENT with Tools =====
def use_preset_agent(query, agent_id):
    """Use a preset agent - has pre-configured tools and settings"""
    print("\n" + "="*70)
    print("METHOD 2: Preset Agent with Tools (Advanced)")
    print("="*70)
    
    # For preset agents, use sessions/query with agentId
    response = requests.post(
        "https://api.on-demand.io/chat/v1/sessions/query",
        headers={
            "apikey": API_KEY,
            "Content-Type": "application/json"
        },
        json={
            "agentId": agent_id,
            "query": query,
            "responseMode": "sync"
        }
    )
    
    result = response.json()
    
    if "error" in result or response.status_code != 200:
        print(f"❌ Error: {result}")
        return result
    
    print(f"Agent ID: {agent_id}")
    print(f"Query: {query}")
    
    if "data" in result:
        data = result["data"]
        print(f"\n📝 Answer:\n{data.get('answer', 'No answer')}")
        
        # Check if tools were used
        if "toolsUsed" in data:
            print(f"\n🔧 Tools Used: {data['toolsUsed']}")
        
        if "metrics" in data:
            print(f"\n📊 Metrics:")
            print(f"  - Tokens: {data['metrics'].get('totalTokens', 0)}")
            print(f"  - Time: {data['metrics'].get('totalTimeSec', 0):.2f}s")
    
    return result


# ===== METHOD 3: Using Preset Agent with Custom Tools =====
def use_agent_with_tools(agent_id, query, tool_ids):
    """Use preset agent with specific tools"""
    print("\n" + "="*70)
    print("METHOD 3: Preset Agent + Specific Tools")
    print("="*70)
    
    response = requests.post(
        "https://api.on-demand.io/chat/v1/sessions/query",
        headers={
            "apikey": API_KEY,
            "Content-Type": "application/json"
        },
        json={
            "agentId": agent_id,
            "query": query,
            "pluginIds": tool_ids,
            "responseMode": "sync"
        }
    )
    
    result = response.json()
    print(f"Agent: {agent_id}")
    print(f"Tools: {tool_ids}")
    print(f"Result: {json.dumps(result, indent=2)[:500]}...")
    return result


if __name__ == "__main__":
    print("\n🤖 Understanding OnDemand.io: Chat Query vs Preset Agents")
    print("="*70)
    
    # Example 1: Basic chat query (what we did before)
    basic_chat_query("What is the stock market?")
    
    # Example 2: Using the Indian Stock Tracker preset agent
    # Agent ID from your image: 672f63c6324e7013db35005e
    INDIAN_STOCK_AGENT = "672f63c6324e7013db35005e"
    
    use_preset_agent(
        query="What is the current performance of Reliance Industries?",
        agent_id=INDIAN_STOCK_AGENT
    )
    
    # Example 3: Try with tools
    # Tool IDs from your image:
    # - Indian Stock Market Fundamental: tool-1728287833
    # - Indian Stock Market News: tool-1728314339
    
    print("\n" + "="*70)
    print("KEY DIFFERENCES:")
    print("="*70)
    print("""
1. BASIC CHAT QUERY:
   - Just AI model knowledge
   - No external data/tools
   - Simple question-answer
   - Uses: endpointId parameter
   
2. PRESET AGENT:
   - Pre-configured with tools
   - Can access real-time data
   - Specialized for specific tasks
   - Uses: agentId parameter
   
3. PRESET AGENT + TOOLS:
   - Agent + specific tools enabled
   - Most powerful option
   - Real-time + specialized knowledge
   - Uses: agentId + pluginIds
    """)
    
    print("\n💡 For Competition:")
    print("  - Chat Query = Simple agent (we have 7 of these)")
    print("  - Preset Agent = Advanced agent with tools")
    print("  - Both count as agents!")
    print("  - Tools = The capabilities agents can use")
