import { TenantDataSourceFactory } from "../../config/tenancy/tenant-ds.factory";
import {
  DataSource,
  DeepPartial,
  EntityManager,
  EntityTarget,
  FindManyOptions,
  FindOneOptions,
  FindOptionsWhere,
  ObjectId,
  ObjectLiteral,
  Repository,
} from "typeorm";
import { QueryDeepPartialEntity } from "typeorm/query-builder/QueryPartialEntity";
import {
  ProcedureNameEnum,
  ProcedureParamMap,
  ProcedureReturnMap,
  procedureParamOrder,
} from "../procedures-documentation/procedure-registry";

export abstract class BaseRepository<T> {
  protected readonly entity: EntityTarget<T>;
  private readonly dsFactory: TenantDataSourceFactory;
  constructor(entity: EntityTarget<T>, dsFactory: TenantDataSourceFactory) {
    this.entity = entity;
    this.dsFactory = dsFactory;
  }
  protected async getDataSource(): Promise<DataSource> {
    return this.dsFactory.get();
  }

  protected async getManager(manager?: EntityManager): Promise<EntityManager> {
    const dataSourceTenant = await this.dsFactory.get();
    const managerTenant = dataSourceTenant.createEntityManager();
    return manager ?? managerTenant;
  }
  protected async getRepo(manager?: EntityManager): Promise<Repository<T>> {
    if (manager) return manager.getRepository(this.entity);
    const ds = await this.dsFactory.get();
    return ds.getRepository(this.entity);
  }
  protected async getRepoByIdentity<E extends ObjectLiteral>(
    identity: EntityTarget<E>,
    manager?: EntityManager,
  ): Promise<Repository<E>> {
    const ds = await this.dsFactory.get();
    if (manager) return manager.getRepository(identity);
    return ds.getRepository(identity);
  }
  async create(data?: DeepPartial<T>, manager?: EntityManager): Promise<T> {
    const repo = await this.getRepo(manager);
    return repo.create(data as DeepPartial<T>);
  }
  async saveMany(
    entities: DeepPartial<T>[],
    manager?: EntityManager,
  ): Promise<T[]> {
    const repo = await this.getRepo(manager);
    return repo.save(entities as any[]);
  }
  async save(entity: DeepPartial<T>, manager?: EntityManager): Promise<T> {
    const repo = await this.getRepo(manager);
    return repo.save(entity as any);
  }
  async update(
    criteria:
      | string
      | string[]
      | number
      | number[]
      | Date
      | Date[]
      | ObjectId
      | ObjectId[]
      | FindOptionsWhere<T>
      | FindOptionsWhere<T>[],
    partialEntity: QueryDeepPartialEntity<T>,
    manager?: EntityManager,
  ) {
    const repo = await this.getRepo(manager);
    return repo.update(criteria, partialEntity);
  }
  async find(options?: FindManyOptions<T>, manager?: EntityManager) {
    const repo = await this.getRepo(manager);
    return repo.find(options);
  }
  async findOne(options: FindOneOptions<T>) {
    const repo = await this.getRepo();
    return repo.findOne(options);
  }
  async delete(
    criteria:
      | string
      | number
      | string[]
      | Date
      | ObjectId
      | number[]
      | Date[]
      | ObjectId[]
      | FindOptionsWhere<T>
      | FindOptionsWhere<T>[],
  ) {
    const repo = await this.getRepo();
    return repo.delete(criteria);
  }

  async executeProcedure<
    N extends ProcedureNameEnum = ProcedureNameEnum,
    S extends boolean | undefined = false,
  >(options: {
    name: N;
    params?: ProcedureParamMap[N];
    isSelect?: boolean;
    transactionalManager?: EntityManager;
    singleResult?: S;
  }): Promise<
    ProcedureReturnMap[N] extends null
      ? null
      : S extends true
        ? ProcedureReturnMap[N] | null
        : ProcedureReturnMap[N][]
  > {
    const {
      name,
      params,
      isSelect = true,
      transactionalManager,
      singleResult = false,
    } = options;
    if (!name) throw new Error("Procedure name is required");
    const paramKeys =
      procedureParamOrder[name].length === 0
        ? (Object.keys(params ?? []) as (keyof ProcedureParamMap[N])[])
        : procedureParamOrder[name];
    const paramValues = paramKeys.map((key) => {
      const keyStr = String(key);
      if (!(keyStr in params)) {
        throw new Error(`Missing param '${keyStr}' for procedure '${name}'`);
      }
      return (params as Record<string, any>)[keyStr];
    });

    const placeholders = paramValues.map((_, i) => `$${i + 1}`).join(", ");
    const query = `${isSelect ? "SELECT * FROM" : "CALL"} ${name}(${placeholders})`;
    //console.log(query, paramValues);
    const runner = await this.getManager(transactionalManager);
    const result = await runner.query(query, paramValues);
    if (!isSelect) return null;
    if (singleResult) return result.length ? result[0] : null;
    return result;
  }
}
