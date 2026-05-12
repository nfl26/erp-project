import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
} from '@nestjs/common';
import { FastifyReply, FastifyRequest } from 'fastify';
import { randomUUID } from 'node:crypto';

const ERROR_SLUGS: Record<number, string> = {
  400: 'bad-request',
  401: 'unauthorized',
  403: 'forbidden',
  404: 'not-found',
  409: 'conflict',
  422: 'validation-error',
  500: 'internal-server-error',
  503: 'service-unavailable',
};

const STATUS_TITLES: Record<number, string> = {
  400: 'Bad Request',
  401: 'Unauthorized',
  403: 'Forbidden',
  404: 'Not Found',
  409: 'Conflict',
  422: 'Unprocessable Entity',
  500: 'Internal Server Error',
  503: 'Service Unavailable',
};

@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<FastifyReply>();
    const request = ctx.getRequest<FastifyRequest>();
    const status = exception.getStatus();
    const exceptionResponse = exception.getResponse();

    const rawMessage =
      typeof exceptionResponse === 'string'
        ? exceptionResponse
        : (exceptionResponse as Record<string, unknown>).message;

    const detail = Array.isArray(rawMessage)
      ? rawMessage.join('; ')
      : String(rawMessage ?? exception.message);

    const traceId =
      (request.headers['x-trace-id'] as string | undefined) ?? randomUUID();

    response.status(status).send({
      type: `https://erp.arteo.cl/errors/${ERROR_SLUGS[status] ?? 'error'}`,
      title: STATUS_TITLES[status] ?? 'Error',
      status,
      detail,
      instance: request.url,
      timestamp: new Date().toISOString(),
      traceId,
    });
  }
}
