import { Injectable, UnauthorizedException, ConflictException, BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from './entities/user.entity';
import { Tutor } from '../usuarios/entities/tutor.entity';
import { Hijo } from '../usuarios/entities/hijo.entity';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Tutor)
    private tutorRepository: Repository<Tutor>,
    @InjectRepository(Hijo)
    private hijoRepository: Repository<Hijo>,
    private jwtService: JwtService,
  ) {
    console.log('AuthService instantiated');
  }

  async register(registerDto: RegisterDto) {
    // Validar si el email ya existe
    const existingUser = await this.userRepository.findOne({
      where: { email: registerDto.email },
    });

    if (existingUser) {
      throw new ConflictException('El email ya está registrado');
    }

    // Validar tipo
    if (!registerDto.tipo || registerDto.tipo.trim() === '') {
      throw new BadRequestException('El campo tipo es requerido');
    }

    const hashedPassword = await bcrypt.hash(registerDto.password, 10);
    
    const tutor = this.tutorRepository.create({
      nombre: registerDto.nombre,
      email: registerDto.email,
      password: hashedPassword,
      tipo: registerDto.tipo.trim(),
    });

    try {
      const savedTutor = await this.tutorRepository.save(tutor);

      const payload = { email: savedTutor.email, sub: savedTutor.id };
      return {
        access_token: this.jwtService.sign(payload),
        user: {
          id: savedTutor.id,
          nombre: savedTutor.nombre,
          email: savedTutor.email,
          tipo: savedTutor.tipo,
        },
      };
    } catch (error) {
      if (error.code === '23505') {
        throw new ConflictException('El email ya está registrado');
      }
      throw new BadRequestException('Error al registrar el tutor');
    }
  }

  async login(loginDto: LoginDto) {
    const user = await this.userRepository.findOne({
      where: { email: loginDto.email },
    });

    if (!user || !(await bcrypt.compare(loginDto.password, user.password))) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    // Incluir el campo tipo en el payload y la respuesta
    const payload = { email: user.email, sub: user.id, tipo: user.tipo };
    return {
      access_token: this.jwtService.sign(payload),
      user: {
        id: user.id,
        nombre: user.nombre,
        email: user.email,
        tipo: user.tipo,
      },
    };
  }

  async validateUser(userId: number): Promise<User | null> {
    return this.userRepository.findOne({ where: { id: userId } });
  }

  async updateFcmToken(userId: number, fcmToken: string): Promise<void> {
    await this.userRepository.update(userId, { fcmToken });
  }

  /**
   * Login con código de vinculación (para hijos)
   */
  async loginConCodigo(codigo: string) {
    const hijo = await this.hijoRepository.findOne({
      where: { codigoVinculacion: codigo.toUpperCase() },
      relations: ['tutores'],
    });

    if (!hijo) {
      throw new UnauthorizedException('Código de vinculación inválido');
    }

    // Marcar como vinculado en el primer login
    if (!hijo.vinculado) {
      hijo.vinculado = true;
      await this.hijoRepository.save(hijo);
    }

    const payload = { email: hijo.email, sub: hijo.id, tipo: 'hijo' };
    return {
      access_token: this.jwtService.sign(payload),
      user: {
        id: hijo.id,
        nombre: hijo.nombre,
        apellido: hijo.apellido,
        email: hijo.email,
        telefono: hijo.telefono,
        vinculado: hijo.vinculado,
        tipo: 'hijo',
      },
    };
  }
}
