import json
import os
import sys

SYSTEM_PROMPT = (
    "You are an intent classifier. Classify the user's prompt into exactly one category.\n"
    "Respond with ONLY the category name, nothing else.\n\n"
    "Categories:\n"
    "- question: asking how, why, what, where, when something works (no change intended)\n"
    "- investigation: exploring a behavior, tracing a bug, understanding code (no change intended)\n"
    "- admin: environment operations — install, update, verify, audit, configure, list tasks, "
    "run diagnostics, check status (no code change)\n"
    "- feature: requests to add new functionality, implement something new\n"
    "- bug: reports of something not working, unexpected behavior\n"
    "- incident: production issues, customer-impacting problems\n"
    "- refactor: requests to improve, simplify, reorganize existing code without new behavior\n\n"
    "If the prompt is a slash command (starts with /), classify as: admin\n"
    "If unsure between question and change, lean toward the change category."
)


def classify(prompt):
    try:
        import anthropic
    except ImportError:
        return "unknown"

    apiKey = os.environ.get("ANTHROPIC_API_KEY")
    if not apiKey:
        return "unknown"

    try:
        client = anthropic.Anthropic(api_key=apiKey)
        response = client.messages.create(
            model="claude-haiku-4-20250414",
            max_tokens=20,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": prompt}],
        )
        intent = response.content[0].text.strip().lower()
        validIntents = {
            "question", "investigation", "admin",
            "feature", "bug", "incident", "refactor",
        }
        if intent in validIntents:
            return intent
        return "unknown"
    except Exception:
        return "unknown"


if __name__ == "__main__":
    prompt = sys.stdin.read().strip()
    if not prompt:
        print("unknown")
        sys.exit(0)
    result = classify(prompt)
    print(result)
