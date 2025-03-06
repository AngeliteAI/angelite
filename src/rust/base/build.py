import os
import sys
from openai import OpenAI

client = OpenAI(
    api_key=os.environ["X_API_KEY"],
    base_url="https://api.x.ai/v1"
)

completion = client.chat.completions.create(
    model="grok-2-latest",
    messages=[
        {"role": "system", "content": os.environ["CHAT_SYSTEM"]},
        {"role": "user", "content": os.environ["CHAT_USER"]},
    ],
)

print(completion, file=sys.stderr)
content = completion.choices[0].message.content

print(f"Debug - Content type: {type(content)}", file=sys.stderr)

print(content) 

