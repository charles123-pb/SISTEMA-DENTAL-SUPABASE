import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

export const permissionGuard: CanActivateFn = (route) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  const permission = route.data['permission'] as string | undefined;
  return !permission || auth.hasPermission(permission)
    ? true
    : router.createUrlTree(['/sistema/inicio'], { queryParams: { denied: permission } });
};
