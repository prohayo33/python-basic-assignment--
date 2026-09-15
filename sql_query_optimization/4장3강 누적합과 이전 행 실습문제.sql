/*
============================================================
[4장 3강] 실습문제: 누적합과 이전 행 비교
============================================================

[실습 목표]
- SUM() OVER를 이용하여 날짜 기준 누적합을 계산할 수 있다.
- ROWS BETWEEN을 이용하여 이동평균 계산 범위를 지정할 수 있다.
- LAG와 LEAD를 이용하여 이전 행과 다음 행의 값을 참조할 수 있다.
- 전일 대비 증감액과 증감률을 계산할 수 있다.
- 계산 결과를 매출 흐름 관점에서 해석할 수 있다.

[사용 환경]
- PostgreSQL
- DBeaver

[사용 데이터]
이번 과정에서는 아래 12개 CSV로 구성된 동일한 Retail Data Warehouse 데이터셋을 계속 사용합니다.

- customers
- employees
- order_items
- orders
- payments
- products
- promotions
- returns
- shipments
- stores
- suppliers
- categories

[이번 강에서 주로 사용하는 테이블]
- orders
- order_items

[주요 관계]
- orders.order_id = order_items.order_id

[주요 컬럼]
orders
- order_id
- order_date
- customer_id
- store_id

order_items
- order_item_id
- order_id
- product_id
- qty
- price

[주의사항]
- 일별 매출은 SUM(order_items.qty * order_items.price)로 계산합니다.
- 먼저 날짜별 매출을 집계한 뒤 윈도우 함수를 적용합니다.
- LAG/LEAD는 ORDER BY 순서상 이전/다음 행을 참조합니다.
*/


/*
============================================================
필수 1. 일별 매출 누적합과 이동평균 계산
============================================================

[문제 1-1] 일별 매출 흐름 확인하기

[문제 설명]
운영팀에서 날짜별 매출과 함께
해당 날짜까지의 누적 매출과 최근 7개 날짜의 평균 매출을 확인하려고 합니다.

먼저 일별 매출을 계산한 뒤
SUM() OVER와 AVG() OVER를 이용하여 누적합과 이동평균을 계산하세요.

[요구사항]
1. orders와 order_items를 order_id 기준으로 JOIN하세요.
2. order_date별 일별 매출을 계산하세요.
3. 일별 매출 컬럼명은 daily_sales로 지정하세요.
4. 일별 매출 결과를 daily_sales_summary라는 CTE로 작성하세요.
5. SUM(daily_sales) OVER를 사용하여
   날짜 순서대로 누적 매출 running_total을 계산하세요.
6. AVG(daily_sales) OVER를 사용하여
   최근 7개 행의 이동평균 moving_avg_7d를 계산하세요.
7. 이동평균의 프레임은 다음과 같이 지정하세요.

   ROWS BETWEEN 6 PRECEDING AND CURRENT ROW

8. 결과는 order_date 오름차순으로 정렬하세요.
9. 다음 질문에 답하세요.
   Q1. running_total은 어떤 범위의 매출을 합산한 값인가요?
    -> 첫번째 날붙터 현재 행까지의 daily_sales를 합산
   Q2. moving_avg_7d는 현재 행을 포함해 최대 몇 개 행을 평균내나요? 
   	-> 7개, 6 preceding현재 행보다 앞의 6개행을 뜻하고 current row까지 포함하여 총 7개
   Q3. 처음 6개 행에서는 왜 정확히 7개 행이 아닌 더 적은 행으로 평균이 계산될 수 있나요? 값이 없어서
    -> 존재하는 범위 안에서만 계산(누적합), 점차 계산 대상 행이 늘어남 

[작성 결과]
- 일별 매출 CTE
- 누적합 및 이동평균 SQL
- Q1~Q3 답변
*/

-- [코드 작성란]
WITH daily_sales_summary AS (
SELECT o.order_date, sum(oi.qty*oi.price)AS daily_sales
FROM orders o JOIN order_items oi ON o.order_id  = oi.order_id 
GROUP BY o.order_date 
)
SELECT order_date, daily_sales,
sum(daily_sales ) OVER (ORDER BY order_date) AS running_total,
avg(daily_sales) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW )AS moving_avg_7d
FROM daily_sales_summary
ORDER BY order_date;




/*
============================================================
필수 2. LAG와 LEAD로 이전·다음 날짜 비교
============================================================

[문제 2-1] 전일·다음날 매출 비교하기

[문제 설명]
매출 담당자가 각 날짜의 매출을 기준으로
이전 날짜와 다음 날짜의 매출을 함께 보고 싶어합니다.

LAG와 LEAD를 이용하여
현재 날짜의 매출 옆에 이전·다음 날짜의 매출을 표시하세요.

[요구사항]
1. orders와 order_items를 이용해 날짜별 daily_sales를 계산하세요.
2. daily_sales_summary CTE를 작성하세요.
3. LAG(daily_sales, 1)을 이용하여 prev_day_sales를 계산하세요.
4. LEAD(daily_sales, 1)을 이용하여 next_day_sales를 계산하세요.
5. daily_sales - prev_day_sales 형태로
   전일 대비 증감액 day_over_day_diff를 계산하세요.
6. 결과를 order_date 오름차순으로 정렬하세요.
7. 다음 질문에 답하세요.
   Q1. 첫 번째 날짜의 prev_day_sales가 NULL인 이유는 무엇인가요?
   	-> 날짜 순서상 첫 번째 행보다 이전에 존재하는 행이 없다.
   Q2. 마지막 날짜의 next_day_sales가 NULL인 이유는 무엇인가요?
   	-> 마지막 행 이후에 참조할 다음 행이 없다.
   Q3. LAG와 LEAD에서 ORDER BY order_date가 중요한 이유는 무엇인가요?
   	-> LAG와 lead가 말하는 이전 행과 다음 행의 순서를 결정하기 때문
   	-> 매출을 비교할 때에는 날짜 기준으로 이전, 다음 매출을 비교할 수 있음

[작성 결과]
- 일별 매출 CTE
- LAG/LEAD SQL
- 전일 대비 증감액
- Q1~Q3 답변
*/

-- [코드 작성란]

WITH daily_sales_summary AS (
SELECT o.order_date , sum(oi.qty * oi.price ) AS daily_sales
FROM orders o JOIN order_items oi ON o.order_id = oi.order_id 
GROUP BY o.order_date 
),
sales_compare as(
SELECT order_date, daily_sales,
lag(daily_sales, 1) OVER (ORDER BY order_date)AS prev_day_sales,
lead(daily_sales, 1) OVER (ORDER BY order_date)AS next_day_sales
FROM daily_sales_summary )
SELECT order_date, daily_sales, prev_day_sales, next_day_sales, (prev_day_sales - next_day_sales) AS day_over_day_dff
FROM sales_compare
ORDER BY order_date;

/*
============================================================
과제. 누적매출과 전일 대비 증감률 분석
============================================================

[문제 3-1] 일별 매출 변화 리포트 만들기

[문제 설명]
운영 리포트에서 다음 정보를 한 번에 확인하려고 합니다.

- 일별 매출
- 해당 날짜까지 누적 매출
- 전일 매출
- 전일 대비 증감액
- 전일 대비 증감률

이번 강에서 배운 SUM() OVER와 LAG를 함께 사용하여
일별 매출 변화 리포트를 작성하세요.

※ 과제는 필수 문제와 동일한 수준입니다.

[요구사항]
1. orders와 order_items를 order_id로 JOIN하세요.
2. order_date별 daily_sales를 계산하세요.
3. daily_sales_summary CTE를 작성하세요.
4. 다음 값을 계산하세요.
   - running_total : 해당 날짜 까지 누적 매출
   - prev_day_sales : 전일 매출
   - day_over_day_diff : 전일 대비 증감액
   - day_over_day_pct : 전일 대비 증감률
5. 전일 대비 증감률은 다음 식을 사용하세요.

   (현재 매출 - 전일 매출) / 전일 매출 * 100

6. 전일 매출이 0인 경우 오류가 발생하지 않도록 NULLIF를 사용하세요.
7. 증감률은 ROUND(..., 2)를 이용해 소수 둘째 자리까지 표시하세요.
8. 결과를 order_date 오름차순으로 정렬하세요.
9. day_over_day_pct가 음수인 날짜만 별도로 조회하세요.
10. 다음 질문에 답하세요.
    Q1. 첫 번째 날짜의 증감률이 NULL이 되는 이유는 무엇인가요?
    Q2. NULLIF(prev_day_sales, 0)를 사용하는 이유는 무엇인가요?
    Q3. day_over_day_pct가 음수라는 것은 비즈니스적으로 무엇을 의미하나요?
    Q4. 하루의 감소만으로 매출 추세가 악화되었다고 단정하기 어려운 이유는 무엇인가요?

[제출 결과]
- 전체 일별 매출 변화 SQL
- 매출 감소 날짜 조회 SQL
- Q1~Q4 답변
*/

-- [코드 작성란]

-- 전체 일별 매출 변화 SQL
WITH daily_sales_first AS (
SELECT order_date, sum(oi.qty * oi.price) AS daily_sales 
FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY order_date
),
daily_sales_summary AS (
SELECT order_date, daily_sales, 
sum(daily_sales) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ) AS running_total, 
lag(daily_sales,1) OVER (ORDER BY order_date) AS prev_day_sales
FROM daily_sales_first
)
SELECT order_date, daily_sales, running_total, prev_day_sales,
(daily_sales - prev_day_sales) AS day_over_day_diff,
round((daily_sales-prev_day_sales) *1.0/ NULLIF(prev_day_sales,0) * 100,2) AS day_over_day_pct
FROM  daily_sales_summary
ORDER BY order_date;

-- 매출 감소 날짜 조회 sql
WITH daily_sales_first AS (
SELECT order_date, sum(oi.qty * oi.price) AS daily_sales 
FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY order_date
),
daily_sales_summary AS (
SELECT order_date, daily_sales, 
sum(daily_sales) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ) AS running_total, 
lag(daily_sales,1) OVER (ORDER BY order_date) AS prev_day_sales
FROM daily_sales_first
),
last_daily_summary AS (
SELECT order_date, daily_sales, running_total, prev_day_sales,
(daily_sales - prev_day_sales) AS day_over_day_diff,
round((daily_sales-prev_day_sales) *1.0/ NULLIF(prev_day_sales,0) * 100,2) AS day_over_day_pct
FROM  daily_sales_summary
ORDER BY order_date)
SELECT *
FROM last_daily_summary
WHERE day_over_day_pct < 0
ORDER BY order_date;



/*
    Q1. 첫 번째 날짜의 증감률이 NULL이 되는 이유는 무엇인가요?
    	- 첫 번째 날짜보다 앞에 날짜는 없어서 증감율을 계산할 prev_day_sales가 없다.
    Q2. NULLIF(prev_day_sales, 0)를 사용하는 이유는 무엇인가요?
    	- 전일 매출이 0인 경우 0으로 나누는 오류가 발생할 수 있기 때문에 전일 매출이 0이면 NULL로 처리하기 위해 사용한다.
    Q3. day_over_day_pct가 음수라는 것은 비즈니스적으로 무엇을 의미하나요?
    	- day_over_day_pct가 음수라는 것은 전날 대비 판매량이 감소했다는 것을 의미한다.
    Q4. 하루의 감소만으로 매출 추세가 악화되었다고 단정하기 어려운 이유는 무엇인가요? 
    	- 하루의 매출 감소는 일시적인 요인이나 우연에 의한 것일 수 있기 때문에, 전체 기간, 이동 흐름, 이동 평균 등 다른 정보도 
    	함께 확인해야 매출 추세가 악화되었다고 판단할 수 있다.
 
 */



/*
============================================================
실습 마무리
============================================================

아래 내용을 한 문단으로 정리하세요.

1. 누적합과 이동평균의 계산 범위는 어떻게 다른가요?
	-> 누적합은 첫 행부터 현재 행까지의 범위를 계속 누적
	-> 이동평균은 형재 행을 기준으로 지정한 최근 N개의 행을 계산
2. LAG와 LEAD는 각각 어떤 행을 참조하나요?
	-> LAG는 ORDER BY 기준 이전 행
	-> LEAD는 다음 행을 참조한다.
3. 전일 대비 증감률 계산에서 NULLIF가 필요한 이유는 무엇인가요?
	-> 전일 매출이 0일 경우, 0으로 나누는 오류가 발생하는 것을 방지하기 위함 
4. 윈도우 함수 결과를 비즈니스 지표로 해석할 때 무엇을 주의해야 하나요?
	-> 하루의 증감이나 하나의 지표만으로 전체 추세를 단정해서는 안됨
	-> 전체 기간, 이동 흐름, 이동 평균, 이벤트 여부 등 다른 정보도 함께 확인 필요
*/
