import { Injectable, UnauthorizedException } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import * as bcrypt from "bcryptjs";
import { user_auth } from "src/users/user.entity";
import { SSemUserModule } from "src/users/user_module.entity";

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(user_auth)
    private userRepository: Repository<user_auth>,

    @InjectRepository(SSemUserModule)
    private userModuleRepository: Repository<SSemUserModule>,

    private jwtService: JwtService,
  ) {}


  async validateUser(username: string, password: string): Promise<any> {
  const user = await this.userRepository.findOne({
    where: { username },
    select: ['id', 'username', 'password', 'alias', 'is_active'] 
  });

  if (user && (await bcrypt.compare(password, user.password))) {
    
    const permissions = await this.userModuleRepository.find({
      where: { 
        userId: user.id, 
        isActive: true, 
      },
      relations: ['module'],
      select: {
        id: true,
        moduleId: true,
        module: {
          id: true,
          code: true,
          name: true,
          route: true
        }
      }
    });

    const hasAccess = permissions.some(p => Number(p.moduleId) === 2);

    if (!hasAccess) {
      throw new UnauthorizedException("No tienes permisos para este sistema.");
    }

    const { password: _, ...result } = user;
    
    const userModules = permissions.map(p => ({
      id: p.module.id,
      code: p.module.code,
      name: p.module.name,
      route: p.module.route
    }));

    return { ...result, modules: userModules };
  }
  return null;
}
  async login(username: string, password: string) {
    const user = await this.validateUser(username, password);

    if (!user) {
      throw new UnauthorizedException("Credenciales inválidas.");
    }

    const payload = { 
      username: user.username, 
      sub: user.id, 
      modules: user.modules 
    };

    return {
      accessToken: this.jwtService.sign(payload),
      user: {
        id: user.id,
        username: user.username,
        alias: user.alias,
        modules: user.modules
      }
    };
  }

  async register(username: string, password: string) {
    const hashedPassword = await bcrypt.hash(password, 10);

    const user = this.userRepository.create({
      username,
      password: hashedPassword,
      is_active: true,
      state_audit: '40001'
    });

    return this.userRepository.save(user);
  }


  generateAccessToken(user: any): string {
    const payload = { 
      username: user.username, 
      sub: user.id || user.id_user, 
      modules: user.modules || [] 
    };
    return this.jwtService.sign(payload);
  }
}