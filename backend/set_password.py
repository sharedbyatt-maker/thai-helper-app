"""Print a hash for ADMIN_PASSWORD_HASH; the password is never echoed or stored."""
import getpass
from werkzeug.security import generate_password_hash

if __name__ == '__main__':
    first = getpass.getpass('New admin password (at least 14 characters): ')
    second = getpass.getpass('Repeat: ')
    if first != second or len(first) < 14:
        raise SystemExit('Passwords must match and contain at least 14 characters.')
    print(generate_password_hash(first))
