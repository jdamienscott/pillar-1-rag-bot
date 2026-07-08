# app/rag.py — retrieval and Bedrock invocation

import boto3
import os
import json
import chromadb
from chromadb.utils import embedding_functions

bedrock   = boto3.client("bedrock-runtime", region_name=os.environ["BEDROCK_REGION"])
MODEL_ID  = os.environ["BEDROCK_MODEL_ID"]

emb = embedding_functions.AmazonBedrockEmbeddingFunction(
    session=boto3.Session(),
    model_name="amazon.titan-embed-text-v2:0",
)

db = chromadb.PersistentClient(path="./chroma")
kb = db.get_or_create_collection("processnexus_kb", embedding_function=emb)


def retrieve(query: str, k: int = 4) -> str:
    results = kb.query(query_texts=[query], n_results=k)
    return "\n\n".join(results["documents"][0])


def invoke_model(prompt: str) -> str:
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1024,
        "messages": [{"role": "user", "content": prompt}],
    })
    resp = bedrock.invoke_model(modelId=MODEL_ID, body=body)
    return json.loads(resp["body"].read())["content"][0]["text"]
