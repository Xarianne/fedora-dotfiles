# 1. Generate the Secure Boot keys locally
generate-keys:
    mkdir -p keys
    @echo "Generating Private Key and DER Certificate..."
    openssl req -new -x509 -newkey rsa:2048 \
        -keyout keys/MOK.priv \
        -out keys/MOK.der \
        -nodes -days 36500 \
        -subj "/CN=BlueRaptor-Owner/" \
        -outform DER
    @echo "Converting to PEM format..."
    openssl x509 -inform DER -in keys/MOK.der -out keys/MOK.pem
    @echo "Keys created in ./keys/"

# 2. Enroll the key into your BIOS (Requires sudo + password setup)
enroll-key:
    @if [ ! -f keys/MOK.der ]; then echo "keys/MOK.der not found! Run 'just generate-keys' first."; exit 1; fi
    @echo "Enrolling key... (You will be asked to CREATE a one-time password)"
    sudo mokutil --import keys/MOK.der
    @echo "Key imported. REBOOT NOW. Select 'Enroll MOK' -> 'Continue' -> 'Yes' -> Enter your password."