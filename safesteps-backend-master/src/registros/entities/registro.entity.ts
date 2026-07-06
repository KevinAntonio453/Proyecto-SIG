import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Hijo } from '../../usuarios/entities/hijo.entity';

@Entity('registros')
export class Registro {
  @PrimaryGeneratedColumn()
  id: number;

  @Column('timestamp', { name: 'hora' })
  hora: Date;

  @Column('double precision', { name: 'latitud' })
  latitud: number;

  @Column('double precision', { name: 'longitud' })
  longitud: number;

  @ManyToOne(() => Hijo, hijo => hijo.id)
  @JoinColumn({ name: 'hijoId' })
  hijo: Hijo;

  @Column({ name: 'hijoId' })
  hijoId: number;

  @Column('boolean', { 
    name: 'fueOffline',
    default: false 
  })
  fueOffline: boolean;

  @Column('timestamp', { 
    name: 'creadoEn',
    default: () => 'CURRENT_TIMESTAMP' 
  })
  creadoEn: Date;
}