import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';

async function bootstrap() {
    const app = await NestFactory.create(AppModule);

    app.setGlobalPrefix('api');            // ej: /api/report/ventas
    app.useGlobalPipes(new ValidationPipe({
        whitelist: true,
        transform: true,
    }));

    // Enable CORS for frontend (Netlify + local dev)
    app.enableCors({
        origin: [ 
            'https://96597ba2.reports-isi-j0d.pages.dev',  // Producción cloudFlare
            'http://localhost:5173',           // Vite dev
            'http://localhost:3000',           // Local testing
        ],
        methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
        credentials: true,
        allowedHeaders: 'Content-Type, Accept, Authorization',
    });

    const port = process.env.PORT || process.env.API_PORT || 3000;
    await app.listen(port);
    console.log(`API corriendo en http://localhost:${port}/api`);
}
bootstrap();
