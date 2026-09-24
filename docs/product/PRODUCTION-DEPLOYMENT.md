# SmartFlow Production Deployment Guide

This guide covers deploying SmartFlow to a production environment for the Municipality of Urbiztondo.

## Pre-Deployment Checklist

### 1. Server Requirements
- **Web Server**: Apache 2.4+ with PHP 8.0+
- **Database**: MySQL 5.7+ or MariaDB 10.3+
- **SSL Certificate**: Valid HTTPS certificate (required for production)
- **PHP Extensions**: pdo_mysql, json, mbstring

### 2. Security Configuration
- [ ] Copy `.env.example` to `.env` and update with production values
- [ ] Set `ALLOW_DEV_TOOLS=false` in `.env`
- [ ] Set strong database password in `.env`
- [ ] Set `CORS_ALLOWED_ORIGINS` to specific domains (not `*`)
- [ ] Set `TOKEN_SECRET` to a random 32+ character string
- [ ] Set `LOG_LEVEL=error` or `warning` (not `debug`)

### 3. Database Setup
```bash
# Import the auth_tokens table for secure session management
mysql -u root -p smartflow < backend/backend/api/auth-tokens-migration.sql

# Or run via PHPMyAdmin:
# Open auth-tokens-migration.sql and execute
```

### 4. Android App Signing
```bash
# Generate release keystore (one-time)
cd mobile/flutter/android
keytool -genkey -v -keystore smartflow-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias smartflow

# Copy keystore.properties.example to keystore.properties
# Fill in the actual values from keystore generation
```

## Deployment Steps

### Backend Deployment

1. **Upload Files**
```bash
# Upload backend/backend/api/* to production server
# Target: /var/www/html/smartflow/api/
```

2. **Configure Environment**
```bash
cd /var/www/html/smartflow/api
cp .env.example .env
nano .env
# Update all values for production
```

3. **Set Permissions**
```bash
chown -R www-data:www-data /var/www/html/smartflow/api
chmod -R 755 /var/www/html/smartflow/api
chmod 600 /var/www/html/smartflow/api/.env
```

4. **Configure Apache**
```apache
# VirtualHost configuration
<VirtualHost *:443>
    ServerName smartflow.urbiztondo.gov.ph
    DocumentRoot /var/www/html/smartflow/api
    
    SSLEngine on
    SSLCertificateFile /path/to/cert.pem
    SSLCertificateKeyFile /path/to/key.pem
    
    <Directory /var/www/html/smartflow/api>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

5. **Test API Health**
```bash
curl https://smartflow.urbiztondo.gov.ph/api/dev-api-health.php
# Should return 403 (dev tools disabled)
```

### Mobile App Deployment

1. **Build Release APK**
```bash
cd mobile/flutter
flutter build apk --release --dart-define=ENV=production
```

2. **Build App Bundle (for Play Store)**
```bash
flutter build appbundle --release --dart-define=ENV=production
```

3. **Distribute**
- Upload APK to internal testing or distribute directly
- For Play Store: Upload app bundle to Google Play Console

### Database Backup Setup

1. **Automated Backups**
```bash
# Add to crontab (daily at 2 AM)
0 2 * * * /path/to/scripts/backup-database.ps1
```

2. **Manual Backup**
```bash
cd /path/to/Capstone\ 1\ -Neil
.\scripts\backup-database.ps1
```

3. **Restore if Needed**
```bash
.\scripts\restore-database.ps1 -BackupFile "backups\smartflow_backup_2024-01-15_02-00-00.sql"
```

## Post-Deployment

### 1. User Account Setup
- Change all default passwords from `smartflow123`
- Create actual LGU staff accounts
- Assign proper office roles

### 2. Monitor Logs
```bash
# Check API logs
tail -f backend/backend/api/logs/smartflow_$(date +%Y-%m-%d).log
```

### 3. Rate Limiting
- Default: 60 requests per minute per user/IP
- Adjust `RATE_LIMIT_PER_MINUTE` in `.env` if needed

### 4. Token Management
- Tokens expire after 24 hours by default
- Users will need to re-login after token expiry
- Revoked tokens are immediately invalidated

## Security Notes

### Critical Security Settings
1. **HTTPS Required**: Android app will reject HTTP in production mode
2. **Dev Tools Disabled**: All `dev-*.php` endpoints return 403
3. **CORS Restricted**: Only specified domains can access API
4. **Secure Tokens**: Stored in database with SHA-256 hashing
5. **Rate Limiting**: Prevents API abuse

### What to Keep Secret
- `.env` file (contains database credentials)
- `keystore.properties` (contains signing keys)
- `smartflow-release.jks` (the keystore file itself)
- Database backups (contain user data)

### Regular Maintenance
- Review logs weekly for suspicious activity
- Update dependencies quarterly
- Backup database before any schema changes
- Rotate SSL certificates before expiry

## Troubleshooting

### API Returns 403
- Check `ALLOW_DEV_TOOLS=false` in `.env`
- Verify CORS origin is in `CORS_ALLOWED_ORIGINS`

### App Won't Connect
- Ensure HTTPS is properly configured
- Check `network_security_config.xml` allows your domain
- Verify `ENV=production` in build command

### Database Connection Failed
- Check database credentials in `.env`
- Verify MySQL service is running
- Check firewall allows localhost connections

## Rollback Procedure

If deployment fails:

1. **Database**
```bash
.\scripts\restore-database.ps1 -BackupFile "backups\smartflow_backup_PRE-DEPLOY.sql"
```

2. **Backend**
```bash
# Restore previous version from git
git checkout <previous-commit-tag>
.\scripts\sync-backend-to-xampp.ps1
```

3. **Mobile**
```bash
# Rebuild with previous version
git checkout <previous-commit-tag>
flutter build apk --release
```

## Support Contact

For deployment issues:
- Technical: smartflow2k26@gmail.com
- Municipal IT: [LGU IT Contact]
