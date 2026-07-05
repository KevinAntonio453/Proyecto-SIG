import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, CreateDateColumn, ManyToMany, JoinTable } from 'typeorm';
import { Tutor } from '../../usuarios/entities/tutor.entity';
import { Hijo } from '../../usuarios/entities/hijo.entity';

@Entity('zonas_seguras')
export class ZonaSegura {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 255 })
  nombre: string;

  @Column({ length: 500, nullable: true })
  descripcion?: string;

  @Column({ type: 'geometry', spatialFeatureType: 'Polygon', srid: 4326 })
  poligono: object; // GeoJSON


  @ManyToOne(() => Tutor, (tutor) => tutor.zonasSeguras, { eager: true })
  tutor: Tutor;

  @ManyToMany(() => Hijo, (hijo) => hijo.zonasSeguras, { eager: true })
  @JoinTable({
    name: 'zona_segura_hijo',
    joinColumn: { name: 'zona_segura_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'hijo_id', referencedColumnName: 'id' },
  })
  hijos: Hijo[];

  @CreateDateColumn({ type: 'timestamp' })
  fechaCreacion: Date;
}