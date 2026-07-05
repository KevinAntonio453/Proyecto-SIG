import { PartialType } from '@nestjs/mapped-types';
import { CreateHijoDto } from './create-hijo.dto';

export class UpdateHijoDto extends PartialType(CreateHijoDto) {}
