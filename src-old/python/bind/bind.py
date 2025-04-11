import os
import sys
from openai import OpenAI

client = OpenAI(
    api_key=os.environ["CHAT_API_KEY"],
    base_url=os.environ["CHAT_BASE_URL"]
)

completion = client.chat.completions.create(
    model=os.environ["CHAT_MODEL"],
    temperature = 0.0,
    messages=[
        {"role": "system", "content": os.environ["CHAT_SYSTEM"]},
        {"role": "user", "content": os.environ["CHAT_USER"]},
    ],
)

print(completion, file=sys.stderr)
content = completion.choices[0].message.content
print(content) 

