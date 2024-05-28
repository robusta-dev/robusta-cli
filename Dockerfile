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

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl \
       gnupg \
       lsb-release \
       unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Google Cloud SDK and Gcloud Auth Plugin
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

RUN apt-get update \
    && apt-get install -y google-cloud-sdk google-cloud-sdk-gke-gcloud-auth-plugin \
    && rm -rf /var/lib/apt/lists/*

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

ENV PYTHONPATH=$PYTHONPATH:.

ENTRYPOINT [ "python", "/app/robusta_cli/main.py"]
