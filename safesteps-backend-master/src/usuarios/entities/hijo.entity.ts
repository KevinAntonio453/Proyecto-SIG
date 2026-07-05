import { Entity, Column, ManyToMany, ChildEntity } from 'typeorm';
import { ZonaSegura } from '../../zonas-seguras/entities/zona-segura.entity';
import { User } from '../../auth/entities/user.entity';
import { Tutor } from './tutor.entity';

@ChildEntity()
export class Hijo extends User {
  @Column({ length: 255, nullable: true })
  apellido: string;

  @Column({ length: 20, nullable: true })
  telefono: string;

  @Column({ type: 'float', nullable: true })
  latitud: number;

  @Column({ type: 'float', nullable: true })
  longitud: number;

  @Column({ type: 'timestamp', nullable: true })
  ultimaconexion: Date;

  @Column({ length: 10, unique: true, nullable: true })
  codigoVinculacion: string;

  @Column({ type: 'boolean', default: false })
  vinculado: boolean;

  @Column({ type: 'varchar', length: 10, default: 'FUERA' })
  estadoZona: 'DENTRO' | 'FUERA';

  @Column({ type: 'int', nullable: true })
  zonaActualId: number;

  @ManyToMany(() => ZonaSegura, (zona) => zona.hijos)
  zonasSeguras: ZonaSegura[];

  @ManyToMany(() => Tutor, (tutor) => tutor.hijos)
  tutores: Tutor[];

}
