import { Entity, Column, ManyToMany, JoinTable, ChildEntity, OneToMany } from 'typeorm';
import { User } from '../../auth/entities/user.entity';
import { Hijo } from './hijo.entity';
import { ZonaSegura } from 'src/zonas-seguras/entities/zona-segura.entity';

@ChildEntity()
export class Tutor extends User {
  @Column({ length: 100 })
  tipo: string;

  @ManyToMany(() => Hijo, (hijo) => hijo.tutores)
  @JoinTable({
    name: 'tutor_hijo',
    joinColumn: { name: 'tutor_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'hijo_id', referencedColumnName: 'id' },
  })
  hijos: Hijo[];
  @OneToMany(() => ZonaSegura, (zona) => zona.tutor)
  zonasSeguras: ZonaSegura[];
}
