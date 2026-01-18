#!/usr/bin/env python3
"""
COMPLETE GUIDE: OnDemand.io Agents vs Tools

This demonstrates:
1. What we've been using (Chat Query Agents)
2. What preset agents are (like Indian Stock Tracker)
3. How tools work with agents
"""

import requests
import json

API_KEY = "eZnzc9TxDXN8LXVV0KI5srq1KYwReaIc"

print("="*80)
print("UNDERSTANDING ONDEMAND.IO: AGENTS vs TOOLS")
print("="*80)

# ===== WHAT WE'VE BEEN USING =====
print("\n📌 TYPE 1: CHAT QUERY AGENTS (What we implemented)")
print("-" * 80)
print("""
These are AI models that answer questions:
- predefined-openai-gpt4o (GPT-4)
- predefined-claude-4-5-opus (Claude)

They work like ChatGPT - answer based on training data.
No real-time data, no external tools by default.
""")

response1 = requests.post(
    "https://api.on-demand.io/chat/v1/sessions/query",
    headers={"apikey": API_KEY, "Content-Type": "application/json"},
    json={
        "query": "What is a stock market?",
        "endpointId": "predefined-openai-gpt4o",
        "responseMode": "sync"
    }
)
result1 = response1.json()
print(f"✅ Example Output: {result1['data']['answer'][:150]}...")

# ===== CHAT QUERY WITH TOOLS =====
print("\n\n📌 TYPE 2: CHAT QUERY + TOOLS (What we also implemented)")
print("-" * 80)
print("""
Same AI models but WITH tools (plugins):
- Web Search plugin: plugin-1712327325
- Weather plugin: plugin-1713962163

Now the AI can search the web for real-time info!
""")

response2 = requests.post(
    "https://api.on-demand.io/chat/v1/sessions/query",
    headers={"apikey": API_KEY, "Content-Type": "application/json"},
    json={
        "query": "Search web for latest AI news",
        "endpointId": "predefined-openai-gpt4o",
        "pluginIds": ["plugin-1712327325"],
        "responseMode": "sync"
    }
)
result2 = response2.json()
print(f"✅ Example Output: {result2['data']['answer'][:150]}...")

# ===== PRESET AGENTS =====
print("\n\n📌 TYPE 3: PRESET AGENTS (Like Indian Stock Tracker)")
print("-" * 80)
print("""
Preset agents are PRE-CONFIGURED setups that include:
- Specific AI model
- Pre-attached tools
- Custom prompts
- Specific settings

Example: Indian Stock Tracker
  Agent ID: 672f63c6324e7013db35005e
  Has tools: 
    - Indian Stock Market Fundamental (tool-1728287833)
    - Indian Stock Market News (tool-1728314339)
  
  This is like a specialized assistant already configured!
  
⚠️ However, these preset agents might be:
   1. Created by other users (not public API)
   2. Require special permissions
   3. Need to be used differently
""")

# Try to use it (may not work with our API key)
response3 = requests.post(
    "https://api.on-demand.io/chat/v1/sessions/query",
    headers={"apikey": API_KEY, "Content-Type": "application/json"},
    json={
        "query": "What is Reliance stock?",
        "endpointId": "672f63c6324e7013db35005e",
        "responseMode": "sync"
    }
)
result3 = response3.json()
print(f"❌ Preset Agent Result: {result3}")
print("   ^ This likely fails because preset agents are user-specific")

# ===== THE EQUIVALENT =====
print("\n\n📌 HOW TO REPLICATE A PRESET AGENT")
print("-" * 80)
print("""
Instead of using a preset agent, we can create the same effect:
1. Use a base AI model (GPT-4)
2. Add the specific tools we want
3. Craft the right prompt

This is what we did in our competition solution!
""")

# Simulating the Indian Stock Tracker behavior
response4 = requests.post(
    "https://api.on-demand.io/chat/v1/sessions/query",
    headers={"apikey": API_KEY, "Content-Type": "application/json"},
    json={
        "query": "Search the web for current Indian stock market trends and news about technology sector",
        "endpointId": "predefined-openai-gpt4o",
        "pluginIds": ["plugin-1712327325"],  # Web search tool
        "responseMode": "sync"
    }
)
result4 = response4.json()
print(f"✅ Our Implementation: {result4['data']['answer'][:200]}...")

# ===== SUMMARY =====
print("\n\n" + "="*80)
print("📊 COMPETITION SUMMARY")
print("="*80)
print("""
✅ WHAT WE IMPLEMENTED:

7 AGENTS (Using Type 1 & 2 approach):
  1. Attendance Analyzer (GPT-4, no tools)
  2. Report Generator (Claude, no tools)
  3. Policy Researcher (GPT-4 + web search tool)
  4. SQL Generator (GPT-4, no tools)
  5. Student Advisor (Claude, no tools)
  6. Multi-Tool Agent (GPT-4 + web + weather tools)
  7. General Query (GPT-4/Claude, optional tools)

3 TOOLS:
  1. Web Search Plugin (plugin-1712327325)
  2. Weather Plugin (plugin-1713962163)
  3. Multi-tool combination

WHY THIS APPROACH WORKS:
- ✅ Type 1 (chat query) = AGENT
- ✅ Type 2 (chat + tools) = AGENT with TOOLS
- ✅ Both count for competition requirements
- ✅ More flexible than preset agents
- ✅ We can customize everything

PRESET AGENTS (Type 3):
- Pre-made by users/OnDemand
- May not be publicly accessible
- Less flexible
- Good for specific repeated tasks
- Our approach achieves the same result!
""")

print("\n💡 KEY INSIGHT:")
print("   Chat Query Agent + Plugin = Preset Agent")
print("   We built 7 custom 'preset agents' for our attendance system!")
print("="*80)
