# To test this locally, run
# docker build -t robusta-cli -f Dockerfile .
# docker run -it --rm --net host -v ~/.aws:/root/.aws -v ~/.config/gcloud:/root/.config/gcloud -v ${PWD}:/workingdir -w=/workingdir -v ~/.kube:/root/.kube robusta-cli robusta gen-config
FROM python:3.12-slim as builder

ENV LANG=C.UTF-8
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/app/venv/bin:$PATH"

WORKDIR /app

RUN pip install poetry==1.8.2

COPY pyproject.toml poetry.lock ./

RUN python -m venv /app/venv && \
    . /app/venv/bin/activate && \
    poetry config virtualenvs.create false && \
    poetry install --no-dev

FROM python:3.12-slim

WORKDIR /app

# We're installing here libexpat1, to upgrade the package to include a fix to 3 high CVEs. CVE-2024-45491,CVE-2024-45490,CVE-2024-45492
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl \
       gnupg \
       lsb-release \
       unzip \
    && apt-get install -y --no-install-recommends libexpat1 \
    && rm -rf /var/lib/apt/lists/*

# Install Google cli so kubectl works w/ gke clusters
RUN curl https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz > /tmp/google-cloud-sdk.tar.gz
RUN mkdir -p /usr/local/gcloud \
  && tar -C /usr/local/gcloud -xvf /tmp/google-cloud-sdk.tar.gz \
  && /usr/local/gcloud/google-cloud-sdk/install.sh
ENV PATH $PATH:/usr/local/gcloud/google-cloud-sdk/bin
RUN gcloud components install gke-gcloud-auth-plugin
RUN gcloud components remove gcloud-crc32c
RUN rm /tmp/google-cloud-sdk.tar.gz
# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip ./aws

# Install Kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin

ENV PYTHONUNBUFFERED=1
ENV PATH="/venv/bin:$PATH"

COPY ./robusta_cli ./robusta_cli
COPY --from=builder /app/venv /venv

# adding /app directory to PYTHONPATH prevents ModuleNotFoundError: No module named 'robusta_cli'
ENV PYTHONPATH=$PYTHONPATH:.:/app

ENTRYPOINT [ "python", "/app/robusta_cli/main.py"]
