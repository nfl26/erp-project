import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import pino from 'pino';

const logger = pino({ name: 'jwt-guard' });

/**
 * Placeholder hasta T-010 (Keycloak/OAuth2).
 * En desarrollo: permite acceso con warning en log.
 * En producción: rechaza toda request (fail-safe).
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    if (process.env['NODE_ENV'] !== 'production') {
      const req = context.switchToHttp().getRequest<{ url: string }>();
      logger.warn({ url: req.url }, 'JwtAuthGuard: placeholder activo — T-010 pendiente');
      return true;
    }
    throw new UnauthorizedException('Autenticación no configurada (T-010 pendiente)');
  }
}
