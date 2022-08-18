# Edge Video Analytics Helm chart 

This chart can be used to deploy [Edge Video Analyics Microservice](https://www.intel.com/content/www/us/en/developer/articles/technical/video-analytics-service.html) on Kubernetes cluster using Helm CLI.

## Usage

### Pre-requisite.

1. Clone this [repo](https://github.com/intel/edge-video-analytics-microservice).
2. Run the following command to make the following files executable:

   ```sh
    chmod +x tools/model_downloader/model_downloader.sh docker/run.sh
   ```

3. Download the required models. From the cloned repo, run the following command:

   ```sh
   ./tools/model_downloader/model_downloader.sh  --model-list <Path to model-list.yml>
   ```

4. After downloading the models, you will have the `models` directory in the base folder. Refer to the following:

   ```json
    models/
    ├── action_recognition
    ├── audio_detection
    ├── emotion_recognition
    ├── face_detection_retail
    ├── object_classification
    └── object_detection
   ```
5. Copy the `models` , `pipelines` and `resources` folder to `/opt/intel/evam/` on the kubernetes worker nodes.

6. Install a [Kubernetes](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/) cluster. 
                          
7. Install [Helm](https://helm.sh) CLI. Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.

### Deployment

- Once the prerequisites are completed properly, install the chart as follows:

   ```console
   helm install evam ./chart/
   ```
- Check the status of deployed application:

   Command:-

   ```console
   helm ls
   ```

   Output:-

   ```console
   NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
   evam    default         1               2022-05-16 16:30:09.118680429 +0530 IST deployed        evam-0.7.2      0.7.2   
   ```
   Command:- 

   ```console
   kubectl get pods  
   ```
   Output:-

   ```console
   NAME                               READY   STATUS    RESTARTS   AGE
   evam-deployment-79b95cdc98-rdcdd   1/1     Running   0          3m2s
   mqtt-deployment-5b87d54794-8mlr6   1/1     Running   0          3m2s 
   ```

### Sending Pipeline Server Requests

   - Get the IP addresses of the evam and mqtt pods running in the cluster.

   ```console
   kubectl get pods -o wide 
   ```

   Sample Output:- 

   ```console
   NAME                               READY   STATUS    RESTARTS   AGE     IP            NODE                 NOMINATED NODE   READINESS GATES
   evam-deployment-79b95cdc98-rdcdd   1/1     Running   0          6m11s   10.144.2.45   kubernetes-worker1   <none>           <none>
   mqtt-deployment-5b87d54794-8mlr6   1/1     Running   0          6m11s   10.144.1.43  kubernetes-worker2   <none>           <none>

   ```
   - From the above IPs trigger the pipeline request as below :- 

   ```console
   curl --location -X POST 'http://10.144.2.45:8080/pipelines/object_detection/person_vehicle_bike' \
--header 'Content-Type: application/json' \
--data-raw '{
  "source": {
      "uri": "https://github.com/intel-iot-devkit/sample-videos/raw/master/person-bicycle-car-detection.mp4?raw=true",
      "type": "uri"
  },
  "destination": {
      "metadata": {
        "type": "mqtt",
        "host": "10.144.1.43:1883",
        "topic": "vaserving"
      }
  }
}'
   ```

   - View Pipeline Results via MQTT

   ```console
   docker run -it  --entrypoint mosquitto_sub  eclipse-mosquitto:1.6 --topic vaserving -p 1883 -h 10.144.1.43
   ```


   ```console
{"objects":[{"detection":{"bounding_box":{"x_max":0.0878419540822506,"x_min":0.0017804615199565887,"y_max":0.3632156252861023,"y_min":0.12948647141456604},"confidence":0.6258460283279419,"label":"vehicle","label_id":2},"h":101,"roi_type":"vehicle","w":66,"x":1,"y":56}],"resolution":{"height":432,"width":768},"source":"https://github.com/intel-iot-devkit/sample-videos/raw/master/person-bicycle-car-detection.mp4?raw=true","timestamp":49000000000}
{"objects":[{"detection":{"bounding_box":{"x_max":0.0731869749724865,"x_min":0.004130329936742783,"y_max":0.35117650032043457,"y_min":0.14347273111343384},"confidence":0.6314214468002319,"label":"vehicle","label_id":2},"h":90,"roi_type":"vehicle","w":53,"x":3,"y":62}],"resolution":{"height":432,"width":768},"source":"https://github.com/intel-iot-devkit/sample-videos/raw/master/person-bicycle-car-detection.mp4?raw=true","timestamp":49083333333}
{"objects":[{"detection":{"bounding_box":{"x_max":0.0626695342361927,"x_min":0.0,"y_max":0.34957605600357056,"y_min":0.14383465051651},"confidence":0.6896529197692871,"label":"vehicle","label_id":2},"h":89,"roi_type":"vehicle","w":48,"x":0,"y":62}],"resolution":{"height":432,"width":768},"source":"https://github.com/intel-iot-devkit/sample-videos/raw/master/person-bicycle-car-detection.mp4?raw=true","timestamp":49166666666}
   ```

## License

[MIT License](../LICENSE)
