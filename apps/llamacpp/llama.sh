# 0) Set vars
NS=llama
DEPLOY=llama-server
CONTAINER=llama-cpp
IMAGE=ghcr.io/ggml-org/llama.cpp:server
SVC=llama-api
PORT=8080

# 1) Patch running deployment image (no git/file changes)
kubectl -n "$NS" set image deployment/"$DEPLOY" "$CONTAINER"="$IMAGE"

# 2) Wait for rollout
kubectl -n "$NS" rollout status deployment/"$DEPLOY" --timeout=180s

# 3) Confirm image actually running
kubectl -n "$NS" get pod -l app="$DEPLOY" -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{.spec.containers[0].image}{"\n"}{end}'

# 4) Check startup/model load logs
kubectl -n "$NS" logs deployment/"$DEPLOY" --tail=200 | egrep -i "load_model|gguf|error|listening|server"

# 5) Smoke test API via port-forward (runs until curl finishes, then kills forward)
kubectl -n "$NS" port-forward svc/"$SVC" "$PORT":"$PORT" >/tmp/llama-pf.log 2>&1 & PF_PID=$!
sleep 2
curl -sS "http://127.0.0.1:$PORT/health" ; echo
curl -sS "http://127.0.0.1:$PORT/v1/models" ; echo
kill $PF_PID

# 6) Roll back quickly if needed
# kubectl -n "$NS" rollout undo deployment/"$DEPLOY"