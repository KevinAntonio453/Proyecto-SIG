import { Entity, PrimaryGeneratedColumn, Column, TableInheritance, Unique } from 'typeorm';

@Entity('users')
@TableInheritance({ column: { type: 'varchar', name: 'type' } })
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 255 })
  nombre: string;

  @Column({ length: 255, nullable: true })
  password: string;

  @Column({ length: 255, unique: true, nullable: true })
  email: string;

  @Column({ type: 'text', nullable: true })
  fcmToken?: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  tipo?: string;
}
