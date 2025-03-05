import os
from openai import OpenAI

client = OpenAI(
    api_key=os.environ["X_API_KEY"]),
    base_url="https://api.x.ai/v1",
)

completion = client.chat.completions.create(
    model="grok-3-latest",
    messages=[
        {"role": "system", "content": os.environ["CHAT_SYSTEM"]},
        {"role": "user", "content": os.environ["CHAT_USER"]},
    ],
)

print(completion)
