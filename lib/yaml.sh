#!/usr/bin/env bash
# YAML generation for OpenShift resources

generate_pvc_yaml() {
  cat <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${PVC_NAME}
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${PVC_SIZE}
  storageClassName: ${STORAGE_CLASS}
EOF
}

generate_deployment_yaml() {
  # Build extra vLLM args YAML
  local extra_args_yaml=""
  if [[ -n "${EXTRA_ARGS:-}" ]]; then
    for arg in $EXTRA_ARGS; do
      extra_args_yaml="${extra_args_yaml}
            - \"${arg}\""
    done
  fi

  # Build extra env vars YAML from EXTRA_ENV array
  # Config files define: EXTRA_ENV=("KEY=value" "KEY2=value2")
  local extra_env_yaml=""
  if [[ ${#EXTRA_ENV[@]:-0} -gt 0 ]]; then
    for entry in "${EXTRA_ENV[@]}"; do
      local key="${entry%%=*}"
      local val="${entry#*=}"
      extra_env_yaml="${extra_env_yaml}
            - name: ${key}
              value: \"${val}\""
    done
  fi

  # Served model name - use SERVED_MODEL_NAME if set, otherwise skip
  local served_name_yaml=""
  if [[ -n "${SERVED_MODEL_NAME:-}" ]]; then
    served_name_yaml="
            - \"--served-model-name\"
            - \"${SERVED_MODEL_NAME}\""
  fi

  cat <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${NAME}
    kueue.x-k8s.io/queue-name: ${QUEUE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${NAME}
  template:
    metadata:
      labels:
        app: ${NAME}
        kueue.x-k8s.io/queue-name: ${QUEUE}
    spec:
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      containers:
        - name: vllm
          image: ${IMAGE}
          imagePullPolicy: IfNotPresent
          args:
            - "--model"
            - "${MODEL}"
            - "--host"
            - "0.0.0.0"
            - "--port"
            - "8000"
            - "--max-model-len"
            - "${MAX_MODEL_LEN}"
            - "--gpu-memory-utilization"
            - "${GPU_UTIL}"
            - "--enable-chunked-prefill"
            - "--enable-prefix-caching"
            - "--max-num-batched-tokens"
            - "${MAX_BATCH_TOKENS}"
            - "--max-num-seqs"
            - "${MAX_SEQS}"
            - "--trust-remote-code"
            - "--tensor-parallel-size"
            - "${TP_SIZE}"${served_name_yaml}${extra_args_yaml}
          env:
            - name: HOME
              value: /tmp
            - name: USER
              value: vllm
            - name: HF_HOME
              value: /tmp/huggingface
            - name: VLLM_CACHE_ROOT
              value: /tmp/vllm
            - name: XDG_CACHE_HOME
              value: /tmp/cache
            - name: TMPDIR
              value: /tmp
            - name: OUTLINES_CACHE_DIR
              value: /tmp/outlines
            - name: FLASHINFER_WORKSPACE_DIR
              value: /tmp/flashinfer
            - name: TORCHINDUCTOR_CACHE_DIR
              value: /tmp/torch_cache
            - name: HUGGING_FACE_HUB_TOKEN
              valueFrom:
                secretKeyRef:
                  name: ${HF_SECRET}
                  key: ${HF_SECRET_KEY}
                  optional: true
            - name: HF_HUB_OFFLINE
              value: "0"
            - name: VLLM_ALLOW_RUNTIME_LORA_UPDATING
              value: "False"${extra_env_yaml}
          ports:
            - name: http
              containerPort: 8000
              protocol: TCP
          resources:
            requests:
              ${GPU_RESOURCE}: "${GPU_COUNT}"
            limits:
              ${GPU_RESOURCE}: "${GPU_COUNT}"
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 120
            periodSeconds: 10
            timeoutSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 180
            periodSeconds: 30
            timeoutSeconds: 10
          volumeMounts:
            - name: model-cache
              mountPath: /model-cache
      volumes:
        - name: model-cache
          persistentVolumeClaim:
            claimName: ${PVC_NAME}
EOF
}

generate_service_yaml() {
  cat <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${NAME}
spec:
  type: ClusterIP
  selector:
    app: ${NAME}
  ports:
    - name: http
      port: 8000
      protocol: TCP
      targetPort: 8000
EOF
}

generate_route_yaml() {
  cat <<EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: ${NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${NAME}
spec:
  to:
    kind: Service
    name: ${NAME}
    weight: 100
  port:
    targetPort: http
EOF
}

generate_all_yaml() {
  generate_pvc_yaml
  echo "---"
  generate_deployment_yaml
  echo "---"
  generate_service_yaml
  if [[ "${EXPOSE:-false}" == true ]]; then
    echo "---"
    generate_route_yaml
  fi
}
