# app/main_guarded.py — guarded RAG bot (AFTER state)
# Same endpoint shape as app/main.py so attack scripts work unchanged.
# Every call now goes through the NeMo Guardrails rail stack.

from fastapi import FastAPI
from nemoguardrails import LLMRails, RailsConfig
import os

config = RailsConfig.from_path(os.environ["NEMOGUARDRAILS_CONFIG"])  # ./rails
rails  = LLMRails(config)

app = FastAPI(title="ProcessNexus Support Bot — GUARDED")


@app.post("/chat")
async def chat(message: str) -> dict:
    # Rail order: input rails → retrieval rails → model call → output rails
    response = await rails.generate_async(
        messages=[{"role": "user", "content": message}]
    )
    return {"answer": response["content"]}
