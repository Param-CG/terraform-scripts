gcloud config set project kong-on-gke-324807
sleep 300

gcloud container clusters get-credentials gke-terraform-cluster-aj --region us-central1 --project kong-on-gke-324807


kubectl create namespace kongtf
kubectl create secret generic kong-enterprise-license --from-file=./license.json -n kongtf
kubectl create secret generic kong-enterprise-superuser-password -n kongtf --from-literal=password=kong
kubectl create secret generic kong-session-config -n kongtf --from-file=admin_gui_session_conf
echo "Installing Kong using HELM CHARTS now........................."
helm install kong kong/kong -n kongtf \
--set env.database=postgres \
--set env.password.valueFrom.secretKeyRef.name=kong-enterprise-superuser-password \
--set env.password.valueFrom.secretKeyRef.key=password \
--set postgresql.enabled=true \
--set postgresql.postgresqlUsername=kong \
--set postgresql.postgresqlDatabase=kong \
--set postgresql.postgresqlPassword=kong \
--set image.repository=kong/kong-gateway \
--set image.tag=2.6.0.1-alpine \
--set admin.enabled=true \
--set admin.http.enabled=true \
--set admin.type=LoadBalancer \
--set ingressController.installCRDs=false \
--set ingressController.image.repository=kong/kubernetes-ingress-controller \
--set ingressController.env.kong_admin_token.valueFrom.secretKeyRef.key=password \
--set ingressController.env.enable_reverse_sync=true \
--set ingressController.env.sync_period="1m" \
--set ingressController.image.tag=2.0.6 \
--set ingressController.env.kong_admin_token.valueFrom.secretKeyRef.name=kong-enterprise-superuser-password \
--set enterprise.enabled=true \
--set enterprise.license_secret=kong-enterprise-license \
--set enterprise.portal.enabled=false \
--set enterprise.smtp.enabled=false \
--set enterprise.rbac.enabled=true \
--set enterprise.rbac.session_conf_secret=kong-session-config \
--set enterprise.rbac.admin_gui_auth_conf_secret=admin-gui-session-conf \
--set manager.type=LoadBalancer
echo "Waiting for Kong installation to complete................"
sleep 120s

echo "Checking for Kong services..............."
kubectl get pod -n kongtf
kubectl get services -n kongtf
echo "Waiting for Kong installation to complete................"
sleep 60

echo "Checking for Kong services..............."
kubectl get pod -n kongtf
kubectl get services -n kongtf

export HOST=$(kubectl get svc --namespace kongtf kong-kong-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $HOST
export PORT=$(kubectl get svc --namespace kongtf kong-kong-proxy -o jsonpath='{.spec.ports[0].port}')
echo $PORT 
export PROXY_IP=${HOST}:${PORT}
kubectl get service kong-kong-admin -n kongtf --output=jsonpath='{.status.loadBalancer.ingress[0].ip}'
export ADMIN_IP=`kubectl get service kong-kong-admin -n kongtf --output=jsonpath='{.status.loadBalancer.ingress[0].ip}'`
export PROXY_IP=$(kubectl get -o jsonpath="{.status.loadBalancer.ingress[0].ip}" service -n kongtf kong-kong-proxy)

echo "Patching deployment kong-kong with ADMIN IP"
kubectl patch deployment kong-kong -n kongtf -p "{\"spec\": { \"template\" : { \"spec\" : {\"containers\":[{\"name\":\"proxy\",\"env\": [{ \"name\" : \"KONG_ADMIN_API_URI\", \"value\": \"$ADMIN_IP:8001\" }]}]}}}}"

echo "Installing Sample Rest API Application for testing"
kubectl apply -f restapiapp.yml
echo "Creating Ingress Controller"
kubectl apply -f my-ingress.yml
echo "Creating Rate Limit Plugin " 
kubectl apply -f kpluginconfig.yml                                                             
echo
echo

echo "-----------------------"
curl "http://$PROXY_IP/digitalhealth/users"
echo "-----------------------"
