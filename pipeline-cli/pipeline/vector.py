from pathlib import Path
from datetime import datetime

CHROMA_PATH = Path.home() / ".claude" / "pipeline" / "chroma"

def getClient():
    try:
        import chromadb
        return chromadb.PersistentClient(path=str(CHROMA_PATH))
    except ImportError:
        return None
    except Exception:
        return None

def isAvailable():
    return getClient() is not None


# --- Source code ---

def searchCode(query, projectId=None, n=10):
    client = getClient()
    if not client:
        return []
    try:
        col = client.get_collection("source_code")
    except Exception:
        return []
    count = col.count()
    if count == 0:
        return []
    where = {"projectId": projectId} if projectId else None
    results = col.query(
        query_texts=[query],
        n_results=min(n, count),
        where=where,
        include=["documents", "metadatas", "distances"],
    )
    if not results["documents"][0]:
        return []
    return [
        {
            "document": doc,
            "metadata": meta,
            "distance": dist,
        }
        for doc, meta, dist in zip(
            results["documents"][0],
            results["metadatas"][0],
            results["distances"][0],
        )
    ]

# --- Requirements ---

def addRequirement(taskId, reqId, text, projectId):
    client = getClient()
    if not client:
        return
    col = client.get_or_create_collection("requirements")
    docId = "{0}:{1}".format(taskId, reqId)
    col.upsert(
        documents=[text],
        ids=[docId],
        metadatas=[{"taskId": taskId, "reqId": reqId, "projectId": projectId or ""}],
    )

def searchRequirements(query, projectId=None, n=5):
    client = getClient()
    if not client:
        return []
    col = client.get_or_create_collection("requirements")
    count = col.count()
    if count == 0:
        return []
    where = {"projectId": projectId} if projectId else None
    results = col.query(
        query_texts=[query],
        n_results=min(n, count),
        where=where,
    )
    if not results["documents"][0]:
        return []
    return [
        {
            "text": doc,
            "id": docId,
            "metadata": meta,
            "distance": dist,
        }
        for doc, docId, meta, dist in zip(
            results["documents"][0],
            results["ids"][0],
            results["metadatas"][0],
            results["distances"][0],
        )
    ]

# --- Context (decisions, lessons, free context) ---

COLLECTION_MAP = {
    "decision": "decisions",
    "lesson": "lessons",
    "context": "context",
}

def addContext(text, contextType, projectId=None, taskId=None):
    client = getClient()
    if not client:
        return
    collectionName = COLLECTION_MAP.get(contextType, "context")
    col = client.get_or_create_collection(collectionName)
    docId = "{0}:{1}".format(contextType, datetime.now().isoformat())
    meta = {"type": contextType, "projectId": projectId or "", "taskId": taskId or ""}
    col.add(documents=[text], ids=[docId], metadatas=[meta])

def searchContext(query, contextType=None, projectId=None, n=5):
    client = getClient()
    if not client:
        return []
    collections = list(COLLECTION_MAP.values()) if not contextType else [COLLECTION_MAP.get(contextType, "context")]
    results = []
    for collectionName in collections:
        try:
            col = client.get_collection(collectionName)
            count = col.count()
            if count == 0:
                continue
            where = {"projectId": projectId} if projectId else None
            queryResults = col.query(
                query_texts=[query],
                n_results=min(n, count),
                where=where,
            )
            for doc, docId, meta, dist in zip(
                queryResults["documents"][0],
                queryResults["ids"][0],
                queryResults["metadatas"][0],
                queryResults["distances"][0],
            ):
                results.append({
                    "text": doc,
                    "id": docId,
                    "metadata": meta,
                    "distance": dist,
                    "collection": collectionName,
                })
        except Exception:
            continue
    results.sort(key=lambda x: x["distance"])
    return results[:n]
