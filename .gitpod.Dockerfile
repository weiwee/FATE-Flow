# Dazzle do not supports ARG TRIGGER_REBUILD=2
FROM gitpod/workspace-full:latest


### Python ###
USER gitpod
RUN pyenv install 3.6.12 \
    && pyenv global 3.6.12 \
    && python3 -m pip install --no-cache-dir --upgrade pip \
    && python3 -m venv ~/py36 \
    && ~/py36/bin/python -m install --no-cache-dir --upgrade pip \    
    && sudo rm -rf /tmp/*