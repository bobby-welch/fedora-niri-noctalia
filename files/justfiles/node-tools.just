# Create the Node.js tools container and export its commands.
setup-node-tools:
    distrobox assemble create \
        --file /usr/share/fedora-niri-noctalia/distrobox/node-tools.ini
