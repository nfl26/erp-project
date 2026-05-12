import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { FastifyReply, FastifyRequest } from 'fastify';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import pino from 'pino';

const logger = pino({ name: 'http' });

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest<FastifyRequest>();
    const { method, url } = req;
    const start = Date.now();

    return next.handle().pipe(
      tap({
        next: () => {
          const res = context.switchToHttp().getResponse<FastifyReply>();
          logger.info({
            method,
            url,
            statusCode: res.statusCode,
            responseTime: Date.now() - start,
          });
        },
        error: (err: Error) => {
          logger.error({
            method,
            url,
            error: err.message,
            responseTime: Date.now() - start,
          });
        },
      }),
    );
  }
}
