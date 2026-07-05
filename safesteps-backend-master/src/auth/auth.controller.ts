import { Controller, Post, Body } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { LoginCodigoDto } from './dto/login-codigo.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {
    console.log('AuthController instantiated');
  }

  @Post('register')
  async register(@Body() registerDto: RegisterDto) {
    return this.authService.register(registerDto);
  }

  @Post('login')
  async login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  /**
   * Login con código de vinculación (para hijos)
   */
  @Post('login-codigo')
  async loginConCodigo(@Body() loginCodigoDto: LoginCodigoDto) {
    return this.authService.loginConCodigo(loginCodigoDto.codigo);
  }
}
