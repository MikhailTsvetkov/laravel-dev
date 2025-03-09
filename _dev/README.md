### Env setup
`cp ./_dev/.env.example .env`

### Docker compose build
`docker compose build --no-cache`

### Set permissions for executable file
`chmod +x ./d`

### Run containers
(`-b` for `composer update` and `npm install`)

`./d up -b`

### Remove containers
(`-v` for remove volumes)

`./d down`

### Vite run build
`./d run build`

### Vite run dev
`./d run dev`

### Artisan
`./d artisan <args>`

### Composer
`./d composer <args>`

### Npm
`./d npm <args>`

### Migrate DB
`./d artisan migrate`
