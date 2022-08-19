# Multimodal Data Visualization Helm chart 

This chart can be used to deploy [ Multimodal Data Visualization](https://www.intel.com/content/www/us/en/developer/articles/technical/multimodal-data-visualization.html) on Kubernetes cluster using Helm CLI.

## Usage

### Pre-requisite.

1. Install a [Kubernetes](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/) cluster. 
                        
2. Install [Helm](https://helm.sh) CLI. Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.

3. Add the system's host IP address in values.yaml file of EVAM helm chart folder. 

4. Install [ EVAM Helm Chart](https://www.intel.com/content/www/us/en/developer/articles/technical/video-analytics-service.html) by following the steps mentioned this document under `Tutorial 4`. 

5. Add the system's host IP address in values.yaml file of multimodal data visualization helm chart folder. 

### Deployment

- Once the prerequisites are completed properly, install the chart as follows:

   ```console
   helm install multimodal-data-visualization ./<DownloadedChart>/
   ```
- Check the status of deployed application:

   Command:-

   ```console
   helm ls
   ```

   Output:-

   ```console
   NAME                             NAMESPACE    REVISION    UPDATED                                    STATUS      CHART                                APP VERSION
   evam                             default      1           2022-07-26 20:58:04.895323101 +0530 IST    deployed    evam-0.7.2                           0.7.2      
   multimodal-data-visualization    default      1           2022-07-26 20:59:04.918583632 +0530 IST    deployed    multimodal-data-visualization-3.0.0    3.0.0  
   ```
   Command:- 

   ```console
   kubectl get pods  
   ```
   Output:-

   ```console
   NAME                                                              READY   STATUS    RESTARTS   AGE
   evam-deployment-57477d7d96-9t6xd                                  1/1     Running   0          4m7s
   mqtt-deployment-5577b74dc-k27xg                                   1/1     Running   0          4m7s
   multimodal-data-visualization-deployment-6459c7c47f-mz6lt         1/1     Running   0          3m9s
   multimodal-data-visualization-streaming-deployment-78fdbd8wlwpc   1/1     Running   0          3m9s
   ```

### Sending Pipeline Server Requests
  
   ```console
   curl localhost:30007/pipelines/object_detection/person_vehicle_bike -X POST -H \
   'Content-Type: application/json' -d \
   '{
   "source": {
   "uri": "https://github.com/intel-iot-devkit/sample-videos/blob/master/person-bicycle-car-detection.mp4?raw=true",
   "type": "uri"
   },
   "destination": {
   "metadata": {
   "type": "file",
   "path": "/tmp/results.txt",
   "format": "json-lines"
   },
   "frame": {
   "type": "webrtc",
   "peer-id": "peerid_1"
   }
   }
   }'
   ```
### Perform the following steps to run Multimodal-Data-Visualization helm chart in EVAM mode:
1. Go to http://<HOST_IP>:30000 to access Multimodal-Data-Visualization.
2. On the Home Dashboard page, on the left corner, click the Dashboards icon.
3. Click the Manage Dashboards tab, to view the list of all the preconfigured dashboards.
4. Select Video Analytics Dashboard, to view the data from the Edge Video Analytics Microservice.
5. Click the Refresh button on the webRTC Stream panel to get the streaming for running pipelines.  

### Perform the following steps to run Multimodal-Data-Visualization helm chart in Standalone mode:

- Set the environment variable `MODE` in values.yaml file as empty present in Multimodal-Data-Visualization.folder.

   ```console
   MODE: 
   ```
- install the helm chart as follows:

   ```console
   helm install multimodal-data-visualization ./<DownloadedChart>/
   ```
 - Go to http://<HOST_IP>:30000 to access Multimodal-Data-Visualization. 
 
 - Select `Sample Visualization Dashboard`, to view the streaming on the Dashboard.
