# app/kb_loader.py — load Markdown KB files into Chroma
# Idempotent: upsert replaces entries with the same ID.
# Re-run after editing KB docs to refresh the index.

import os
import glob
import boto3
import chromadb
from chromadb.utils import embedding_functions

emb = embedding_functions.AmazonBedrockEmbeddingFunction(
    session=boto3.Session(),
    model_name="amazon.titan-embed-text-v2:0",
)

db = chromadb.PersistentClient(path="./chroma")
kb = db.get_or_create_collection("processnexus_kb", embedding_function=emb)

KB_DIR = os.path.join(os.path.dirname(__file__), "kb")

docs, ids = [], []
for path in sorted(glob.glob(f"{KB_DIR}/*.md")):
    docs.append(open(path).read())
    ids.append(os.path.basename(path))

kb.upsert(documents=docs, ids=ids)
print(f"Loaded {len(docs)} documents into Chroma: {ids}")
