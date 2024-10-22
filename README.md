
# E-commerce Microservices Setup (Work in Progress)

This project sets up a simple E-commerce platform using microservices architecture. The setup includes an API Gateway, Product and Order services, a frontend, RabbitMQ, and a PostgreSQL database.

## Overview

### Services
- **API Gateway**: Handles routing requests to the respective services.
- **Product Service**: Manages product data.
- **Order Service**: Handles order creation and retrieval.
- **Frontend**: A React-based frontend for interacting with the E-commerce platform.
- **RabbitMQ**: Used for communication between services (e.g., handling order events).
- **PostgreSQL**: A database for storing product and order data.

### Project Status
This project is currently a work in progress. Some components may be incomplete or subject to change.

## Setup Instructions

### Prerequisites
- Docker and Docker Compose installed on your system.

### Environment Variables
Create a `.env` file in the `ecommerce` directory with the following content:
```
POSTGRES_USER=admin_postgres
POSTGRES_PASSWORD=123
POSTGRES_DB=products
RABBITMQ_DEFAULT_USER=admin_rabbit
RABBITMQ_DEFAULT_PASS=123
```

### Running the Services
To start all services, navigate to the `ecommerce` directory and run:
```bash
docker-compose up --build
```

### Accessing the Services
- **Frontend**: [http://localhost:8080](http://localhost:8080)
- **API Gateway**: [http://localhost:3000](http://localhost:3000)
- **RabbitMQ Management UI**: [http://localhost:15672](http://localhost:15672)
- **Product Service**: [http://localhost:4000/products](http://localhost:4000/products)
- **Order Service**: [http://localhost:5000/orders](http://localhost:5000/orders)

### Database Initialization
The PostgreSQL database will be initialized using the `init.sql` file. It creates the necessary `products` and `orders` tables if they do not exist.

## Directory Structure
```
ecommerce/
├── api-gateway/
│   ├── Dockerfile
│   └── index.js
├── frontend/
│   ├── Dockerfile
│   ├── public/
│   └── src/
├── product-service/
│   ├── Dockerfile
│   └── index.js
├── order-service/
│   ├── Dockerfile
│   └── index.js
├── db/
│   ├── init.sql.template
│   └── init.sql
├── docker-compose.yml
├── .env
└── prebuild.sh
```

### Notes
- Ensure that the environment variables are correctly set up before running the project.
- This setup is intended for local development and testing purposes only.
- Use the `prebuild.sh` script to generate `init.sql` before starting the services if changes are made to the `init.sql.template`.

### To-Do
- [ ] Implement more comprehensive error handling.
- [ ] Improve documentation for each service.
- [ ] Add automated tests for services.
- [ ] Enhance frontend design.

## License
This project is open-source and available under the MIT License.

---

**Disclaimer**: This project is still in development. Some features may be incomplete or non-functional.
