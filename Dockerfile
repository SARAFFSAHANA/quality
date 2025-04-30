FROM php:7.4-apache

# Install system packages and PHP extensions
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libzip-dev \
    zip \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    default-mysql-client \
    && docker-php-ext-install pdo pdo_mysql mbstring xml zip

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Set Apache DocumentRoot to /var/www/html/web (Yii2 public directory)
RUN sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/web|' /etc/apache2/sites-available/000-default.conf

# Allow .htaccess overrides
RUN echo '<Directory /var/www/html/web>\n\
    AllowOverride All\n\
    Require all granted\n\
</Directory>' >> /etc/apache2/apache2.conf

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy project files into container
COPY . .

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# Install PHP dependencies
RUN composer install --no-interaction --prefer-dist --optimize-autoloader

# Inject secure cookieValidationKey dynamically
RUN mv config/web.php config/web.original.php && \
    KEY=$(php -r "echo bin2hex(random_bytes(32));") && \
    echo "<?php" > config/web.php && \
    echo "\$config = require(__DIR__ . '/web.original.php');" >> config/web.php && \
    echo "\$config['components']['request']['cookieValidationKey'] = '${KEY}';" >> config/web.php && \
    echo "return \$config;" >> config/web.php

# Expose Apache port
EXPOSE 80
