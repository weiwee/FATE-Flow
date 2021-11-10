# Dazzle do not supports ARG TRIGGER_REBUILD=2
FROM gitpod/workspace-full:latest


### Python ###
USER root
RUN mkdir -p /venv && chown gitpod:gitpod /venv

USER gitpod
ENV PIP_USER=
ENV PYTHONUSERBASE=
RUN pyenv install 3.6.15 \
    && pyenv global 3.6.15 \
    && python3 -m venv /venv/py36 \
    && /venv/py36/bin/python -m pip install --no-cache-dir --upgrade pip \    
    && sudo rm -rf /tmp/*