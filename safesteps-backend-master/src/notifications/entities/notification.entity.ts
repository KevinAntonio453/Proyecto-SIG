import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
} from 'typeorm';
import { Tutor } from '../../usuarios/entities/tutor.entity';

@Entity('notifications')
export class Notification {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 500 })
  mensaje: string;

  @Column({ length: 50 })
  tipo: string;

  @Column({ type: 'boolean', default: false })
  leida: boolean;

  @Column({ name: 'tutor_id' })
  tutorId: number;

  @ManyToOne(() => Tutor, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tutor_id' })
  tutor: Tutor;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
