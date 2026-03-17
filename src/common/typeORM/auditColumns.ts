import {
	Column,
	ColumnOptions,
	CreateDateColumn,
	UpdateDateColumn,
} from "typeorm";

export function CreateColumCustom(
	options: ColumnOptions = {},
): PropertyDecorator {
	return CreateDateColumn({
		name: "created_at",
		type: "timestamptz",
		default: () => "CURRENT_TIMESTAMP",

		...options,
	});
}


export function UpdateColumCustom(
	options: ColumnOptions = {},
): PropertyDecorator {
	return UpdateDateColumn({
		name: "updated_at",
		type: "timestamptz",
		nullable: true,
		...options,
	});
}



export function CreatedByColumCustom(
	options: ColumnOptions = {},
): PropertyDecorator {
	return Column({
		name: "created_by",
		type: "uuid",
		nullable: true,
		...options,
	});
}

export function UpdateByColumCustom(
	options: ColumnOptions = {},
): PropertyDecorator {
	return Column({
		name: "updated_by",
		type: "uuid",
		nullable: true,
		...options,
	});
}
