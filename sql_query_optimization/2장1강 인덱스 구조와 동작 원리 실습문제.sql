/*
============================================================
[2장 1강] 실습문제: 인덱스 구조와 동작 원리
============================================================

[실습 목표]
- B-Tree 인덱스가 검색 범위를 줄여 데이터를 탐색하는 원리를 이해할 수 있다.
- CREATE INDEX와 DROP INDEX를 이용하여 인덱스를 생성하고 삭제할 수 있다.
- EXPLAIN ANALYZE를 이용하여 인덱스 생성 전후의 실행계획을 비교할 수 있다.
- pg_indexes를 이용하여 생성된 인덱스 목록을 확인할 수 있다.
- 인덱스 생성에 따라 INSERT, UPDATE, DELETE 시 추가 작업이 필요한 이유를 설명할 수 있다.

[사용 환경]
- PostgreSQL
- DBeaver

[사용 데이터]
- orders      : 300,000행
- products    : 10,000행

[주의사항]
- 실행 시간과 cost는 PostgreSQL 환경에 따라 달라질 수 있습니다.
- 특정 실행계획 형태를 정답으로 고정하지 않습니다.
- 학생은 자신의 EXPLAIN ANALYZE 결과를 기준으로 작성합니다.
*/


/*
============================================================
실습 준비
============================================================
*/

SELECT COUNT(*) AS order_count
FROM orders;

SELECT COUNT(*) AS product_count
FROM products;


/*
============================================================
필수 1. customer_id 인덱스 생성 전후 비교
============================================================

[문제 1-1]

[문제 설명]
orders에서 특정 고객의 주문을 조회할 때
customer_id 인덱스 생성 전후의 실행계획이 어떻게 달라지는지 확인하세요.

[요구사항]
1. idx_orders_customer_id 인덱스가 있다면 삭제하세요.
2. customer_id = 31428 조건으로 주문을 조회하고 EXPLAIN ANALYZE를 적용하세요.
3. 인덱스 생성 전 실행계획에서 다음 항목을 기록하세요.
   - 스캔 방식 : seq scan
   - cost : 0.00..4116.88
   - actual rows : 9.50 loop=2
   - Execution Time : 61.234ms
4. orders.customer_id에 idx_orders_customer_id 인덱스를 생성하세요.
5. 동일한 SELECT문에 다시 EXPLAIN ANALYZE를 적용하세요.
6. 인덱스 생성 후 실행계획에서 다음 항목을 기록하세요.
   - 스캔 방식: index scan
   - cost : 0.00..4.48
   - actual rows: 19 loop=1
   - Execution Time: 0.176 ms
7. 인덱스 생성 전후 결과를 비교하세요.
8. 다음 질문에 답하세요.
   Q1. 인덱스 생성 전과 후의 스캔 방식은 어떻게 달라졌나요? seq scan -> index scan으로 변경됨
   Q2. B-Tree 인덱스가 customer_id = 31428을 찾을 때
       모든 주문을 처음부터 확인하지 않아도 되는 이유는 무엇인가요?
       - B-Tree는 키 값을 정렬된 트리 구조로 저장
       - 따라서 1번부터 2..3..번 순서로 스캔하지 않고 테이블 행 모두를 한 번에 확인하여
       - 검색범위를 좁혀서 속도가 빠름
   Q3. cost와 Execution Time은 같은 의미인가요?
   	  - cost는 옵티마이저가 예상한 상대적인 비용
   	  - Execution time은 Explain analyze에서 실제 실행 후 측정된 시간   

[제출 결과]
- DROP INDEX 문
- 인덱스 생성 전 EXPLAIN ANALYZE
- 개선 전 기록표
- CREATE INDEX 문
- 인덱스 생성 후 EXPLAIN ANALYZE
- 개선 후 기록표
- 전후 비교
- Q1~Q3 답변
*/

-- [코드 작성란]
--요구사항 1 -> 기존 인덱스 삭제
DROP INDEX IF EXISTS idx_orders_customer_id;

--요구사항 2 -->조회
EXPLAIN ANALYZE
SELECT *
FROM orders
WHERE customer_id=31428;

--요구사항 4 --> index 생성
CREATE INDEX idx_orders_customer_id ON orders(customer_id);

--요구사항 5 --> 다시 explain analyze 적용
EXPLAIN ANALYZE
SELECT *
FROM orders
WHERE customer_id=31428;


/*
============================================================
필수 2. 인덱스 생성·확인·삭제와 쓰기 비용 이해
============================================================

[문제 2-1]

[문제 설명]
products 테이블의 category_id와 supplier_id 컬럼에
실습용 B-Tree 인덱스를 생성하고,
PostgreSQL 시스템 뷰에서 생성 결과를 확인한 뒤 삭제하세요.

인덱스 생성과 삭제 문법을 익히고,
테이블의 데이터가 변경될 때 관련 인덱스에도 추가 작업이 필요한 이유를 설명하세요.

[요구사항]
1. 다음 실습용 인덱스가 있다면 삭제하세요.
   - idx_products_category_practice
   - idx_products_supplier_practice
2. products.category_id에 idx_products_category_practice 인덱스를 생성하세요.
3. products.supplier_id에 idx_products_supplier_practice 인덱스를 생성하세요.
4. pg_indexes에서 products 테이블의 인덱스 이름과 정의를 조회하세요.
5. 조회 결과에서 두 실습용 인덱스가 생성되었는지 확인하세요.
6. 두 실습용 인덱스를 삭제하세요.
7. pg_indexes를 다시 조회하여 두 인덱스가 삭제되었는지 확인하세요.
8. 다음 질문에 답하세요.
   Q1. CREATE INDEX와 DROP INDEX는 각각 어떤 작업을 수행하나요?
   	- create index는 지정한 컬럼 값을 기반으로 인덱스 구조를 생성
   	- drop index는 해당 인덱스 구조를 삭제
   	
   Q2. INSERT 시 테이블 외에 인덱스에도 추가 작업이 필요한 이유는 무엇인가요?
   	- 새 행의 인덱스 대상 컬럼 값과 테이블 위치 정보를 관련 인덱스의 정렬된 구조에도 추가해야 하기 때문
   	
   Q3. 인덱스 컬럼을 UPDATE하거나 행을 DELETE할 때 인덱스에는 어떤 작업이 필요한가요?
   	- 인덱스 대상 값이 변경되면 새 값과 행 버전에 맞는 인덱스 항목 필요

[제출 결과]
- 기존 실습용 인덱스 DROP INDEX 문
- 두 개의 CREATE INDEX 문
- pg_indexes 확인 SQL과 생성 확인 결과
- 두 개의 DROP INDEX 문
- pg_indexes 재확인 SQL과 삭제 확인 결과
- 쓰기 작업 시 인덱스 유지 비용에 대한 설명
- Q1~Q3 답변
*/

-- [코드 작성란]
-- 1. 실습용 인덱스 삭제하기
DROP INDEX IF EXISTS idx_products_category_practice;
DROP INDEX IF EXISTS idx_products_supplier_practice;

-- 2,3. 인덱스 생성하기
CREATE INDEX idx_products_category_practice ON products(category_id);
CREATE INDEX idx_products_supplier_practice ON products(supplier_id);

-- 4. products 테이블의 인덱스 이름과 정의 조회
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename='products'
ORDER by indexname;

-- 6. 인덱스 다시 삭제
DROP INDEX IF EXISTS idx_products_category_practice;
DROP INDEX IF EXISTS idx_products_supplier_practice;

--7. 다시 조회
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename='products'
ORDER by indexname;


/*
============================================================
과제. 범위 검색에서 B-Tree 인덱스 확인
============================================================

[문제 3-1]

[문제 설명]
products.price에 B-Tree 인덱스를 생성하고
price가 100 이상 120 미만인 범위 조회의 실행계획을 비교하세요.

※ 필수 문제와 동일한 수준의 독립 실습입니다.

[요구사항]
1. products.price의 최솟값과 최댓값을 확인하세요.
2. idx_products_price 인덱스가 있다면 삭제하세요.
3. price >= 100 AND price < 120 조건에 EXPLAIN ANALYZE를 적용하세요.
4. 인덱스 생성 전 다음 항목을 기록하세요.
   - 스캔 방식
   - cost
   - actual rows
   - Execution Time
5. products.price에 idx_products_price 인덱스를 생성하세요.
6. 동일한 SELECT문에 다시 EXPLAIN ANALYZE를 적용하세요.
7. 인덱스 생성 후 다음 항목을 기록하세요.
   - 스캔 방식
   - cost
   - actual rows
   - Execution Time
8. 인덱스 생성 전후 결과를 비교하세요.
9. 실습이 끝나면 idx_products_price 인덱스를 삭제하세요.
10. 다음 질문에 답하세요.
    Q1. B-Tree 인덱스는 등호 검색 외에 어떤 비교 조건에 활용될 수 있나요?
    Q2. B-Tree 인덱스가 범위 검색에서 검색 범위를 줄일 수 있는 이유는 무엇인가요?
    Q3. 인덱스를 많이 만들수록 INSERT, UPDATE, DELETE 비용이 커질 수 있는 이유는 무엇인가요?

[제출 결과]
- MIN/MAX 확인 SQL
- DROP INDEX 문
- 인덱스 생성 전 EXPLAIN ANALYZE
- 개선 전 기록표
- CREATE INDEX 문
- 인덱스 생성 후 EXPLAIN ANALYZE
- 개선 후 기록표
- 전후 비교
- 최종 DROP INDEX 문
- Q1~Q3 답변
*/

-- [코드 작성란]
-- MIN/MAX 확인 SQL
SELECT min(price) AS min_price , max(price)AS max_price
FROM products p;

-- DROP INDEX 문
DROP INDEX IF EXISTS idx_products_price;

-- 인덱스 생성 전 EXPLAIN ANALYZE
EXPLAIN analyze
SELECT *
FROM products p
WHERE price>100 AND price<120;

-- 개선 전 기록표
--   - 스캔 방식: Seq Scan
--   - cost: 0.00..205.00
--   - actual rows: 31
--   - Execution Time: 0.318ms

-- CREATE INDEX 문
CREATE INDEX idx_products_price ON products(price);

-- 다시 적용
EXPLAIN analyze
SELECT *
FROM products p
WHERE price>100 AND price<120;

-- 인덱스 생성 후
--   - 스캔 방식: Bitmap Index Scan
--   - cost: 0.00..4.69
--   - actual rows: 31
--   - Execution Time: 0.050 ms

-- 인덱스 생성 전후 결과를 비교하세요.
--	- 인덱스 생성 전에는 Seq Scan으로 테이블을 처음부터 조회했지만, 인덱스 생성 이후에는 Bitmap Index로 바뀌었다.
--	옵티머스가 시간을 계산하는 상대적인 값인 cost는 index 적용 이후 205.00에서 4.69로 크게 줄었으며 
-- 	실제 실행시간 역시 0.318ms 에서 0.050ms로 크게 줄었다.

-- idx_products_price 인덱스 삭제
DROP INDEX IF EXISTS idx_products_price;


/*
    Q1. B-Tree 인덱스는 등호 검색 외에 어떤 비교 조건에 활용될 수 있나요?
    	->  >, >=, <, <=, BETWEEN
    Q2. B-Tree 인덱스가 범위 검색에서 검색 범위를 줄일 수 있는 이유는 무엇인가요?
    	-> B-Tree는 정렬되어 있기 때문에 어디서부터 어디까지 보면 되는지가 명확해져서 범위를 줄일 수 있다.
    Q3. 인덱스를 많이 만들수록 INSERT, UPDATE, DELETE 비용이 커질 수 있는 이유는 무엇인가요?
	    -> 인덱스 개수만큼 유지하고 관리해야 할 정렬 구조가 늘어나기 때문에 데이터 변경 시 그 모든 구조를 함께 갱신해야 해서 비용이 커진다.
*/

/*
============================================================
실습 마무리
============================================================

1. B-Tree 인덱스가 검색 속도를 높일 수 있는 핵심 원리는 무엇인가요?
	- B-Tree는 키를 정렬된 트리구조로 관리하여 전체 데이터를 순서대로 읽지 않고 검색 범위를 줄일수 있다.
2. B-Tree 인덱스는 등호 검색과 범위 검색에서 각각 어떻게 활용될 수 있나요?
	- 등호 검색에서는 정렬된 트리를 따라 특정 키가 있는 위치로 이동
	- 범위 검색에서는 범위의 시작 위치를 찾은 뒤 해당 구간을 따라 검색
	
3. 인덱스를 만들 때 조회 성능뿐 아니라 쓰기 성능도 고려해야 하는 이유는 무엇인가요?
	- INSERT/DELETE/UPDATE 시 테이블뿐 아니라 관련 인덱스의 항목 추가 및 유지 그리고 과거 항목 정리가 필요할 수 있다.
	
*/
