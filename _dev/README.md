# Development


### Set permissions for executable file
```
chmod +x ./x
```


## Laravel installation (for new projects)

### 1. Copy the `.env` file if needed
```
cp _dev/.env.example.development .env
```
Edit the `.env` file as you need.

### 2. Install Laravel 11
Or another version that supports PHP 8.4
```
./x install laravel:11
```


## Project setup

### 1. Copy the `.env` file if needed
```
cp .env.example.development .env
```
Edit the `.env` file as you need.

### 2. Run the services
(`-b` for `composer install` and `npm install`)
```
./x up -b
```

### 3. Run database migrations
```
./x artisan migrate
```



### Stop the services
(`-v` for remove volumes)
```
./d down
```

### Vite run build
```
./d run build
```

### Vite run dev
```
./d run dev
```

### Artisan
```
./d artisan <args>
```

### Composer
```
./d composer <args>
```

### Npm
```
./d npm <args>
```
