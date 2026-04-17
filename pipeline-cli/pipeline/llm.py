import os

_HAIKU_MODEL = "claude-haiku-4-5-20251001"

_EXPAND_PROMPT = (
    "Translate the following search query to English technical terms suitable for "
    "searching source code. Return only the expanded query, no explanation.\n\nQuery: {query}"
)


def expandQuery(query):
    apiKey = os.environ.get("ANTHROPIC_API_KEY")
    if not apiKey:
        return query
    try:
        import anthropic
        client = anthropic.Anthropic(api_key=apiKey)
        message = client.messages.create(
            model=_HAIKU_MODEL,
            max_tokens=64,
            messages=[{"role": "user", "content": _EXPAND_PROMPT.format(query=query)}],
        )
        return message.content[0].text.strip()
    except Exception:
        return query
