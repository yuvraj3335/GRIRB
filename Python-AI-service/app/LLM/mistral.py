import os
from mistralai import Mistral


api_key = os.getenv("MISTRAL_API_KEY")
client = Mistral(api_key=api_key)

def make_llm_call(prompt: str) -> str:
    """
    Calls Mistral API to generate text based on the given prompt.
    Returns the generated text as a string.
    """
    try:
        response = client.chat.completions.create(
            model="mistral-large",  
            messages=[{"role": "user", "content": prompt}]
        )
        return response.choices[0].message.content
    except Exception as e:
        raise Exception(f"Mistral API error: {str(e)}")

