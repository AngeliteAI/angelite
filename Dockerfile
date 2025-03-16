# Dockerfile generated from snippets

# From snippet: 000_arch
FROM fedora:latest

# Update system and install development packages
RUN dnf update -y 
RUN dnf install @development-tools -y
RUN dnf install wget -y

ARG WORKSPACE 


# From snippet: 100_entry
CMD ["bash"]


