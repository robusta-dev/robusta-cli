import json
import random
from typing import List

from hikaru.model.rel_1_26 import Container, Job, JobSpec, ObjectMeta, PodSpec, PodTemplateSpec, SecurityContext
from kubernetes import client, config
from robusta.integrations.prometheus.utils import AlertManagerDiscovery


class AlertManagerException(Exception):
    def __init__(self, message: str):
        super().__init__(message)
        self.message = message


def create_demo_alert(
    alertmanager_url: str,
    namespaces: List[str],
    alert: str,
    labels: str,
    kube_config: str,
    image: str
):
    config.load_kube_config(kube_config)
    if not alertmanager_url:
        # search cluster alertmanager by known alertmanager labels
        alertmanager_url = AlertManagerDiscovery.find_alert_manager_url()
        if not alertmanager_url:
            raise AlertManagerException("Alertmanager service could not be auto-discovered. Please use the --alertmanager-url parameter")

    pod = None
    for namespace in namespaces:
        pods = client.CoreV1Api().list_namespaced_pod(namespace)
        if pods.items:
            pod = pods.items[0]
            break

    if not pod:
        raise AlertManagerException(f"Could not find any pod on namespace {namespaces}. Please use the --namespaces parameter to specify a namespace with pods")

    alert_labels = {
        "alertname": alert,
        "severity": "critical",
        "pod": pod.metadata.name,
        "namespace": pod.metadata.namespace,
    }
    if labels:
        for label in labels.split(","):
            label_key = label.split("=")[0].strip()
            label_value = label.split("=")[1].strip()
            alert_labels[label_key] = label_value

    demo_alerts = [
        {
            "status": "firing",
            "labels": alert_labels,
            "annotations": {
                "summary": "This is a demo alert manager alert created by Robusta",
                "description": "Nothing wrong here. This alert will be resolved soon",
            },
        }
    ]

    command = [
        "curl",
        "-X",
        "POST",
        f"{alertmanager_url}/api/v1/alerts",
        "-H",
        "Content-Type: application/json",
        "-d",
        f"{json.dumps(demo_alerts)}",
    ]

    job: Job = Job(
        metadata=ObjectMeta(
            name=f"alert-job-{random.randint(0, 10000)}",
            namespace=pod.metadata.namespace,
        ),
        spec=JobSpec(
            template=PodTemplateSpec(
                spec=PodSpec(
                    containers=[
                        Container(
                            name="alert-curl",
                            image=image,
                            command=command,
                            securityContext=SecurityContext(runAsUser=2000),
                        )
                    ],
                    restartPolicy="Never",
                ),
            ),
            completions=1,
            ttlSecondsAfterFinished=0,  # delete immediately when finished
        ),
    )
    job.create()
    return pod.metadata.name, pod.metadata.namespace