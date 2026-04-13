FROM php:8.2-apache

# Enable mod_rewrite (needed for .htaccess)
RUN a2enmod rewrite

# Allow .htaccess files to work (sets AllowOverride All for /var/www/html)
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' \
        /etc/apache2/apache2.conf; \
    printf '<Directory /var/www/html>\n\tAllowOverride All\n\tRequire all granted\n</Directory>\n' \
        > /etc/apache2/conf-available/mgh-ctf.conf; \
    a2enconf mgh-ctf

# Copy portal files to web root
COPY web/patient-portal/ /var/www/html/

# Copy hospital files alongside the portal (direct HTTP access blocked by .htaccess)
COPY hospital-files/ /var/www/html/hospital-files/

# The SQLite database is created on first request inside includes/.
# Give www-data write permission on that directory.
RUN chown -R www-data:www-data /var/www/html/includes && \
    chmod 755 /var/www/html/includes

EXPOSE 80
